# FIX-ALIAS-CHAIN-WRONG-COALITION — une seule coalition pour toute la chaîne

Status: ✅ done

Trouvé en jeu le 2026-08-25. David : *« "-arty1" me dit "no allied group within 250m of the marker" »*,
puis, quand j'ai affirmé que la batterie apparaissait rouge : *« t'es sûr que "-arty1" fait apparaitre un
groupe rouge ? moi je vois un groupe bleu quand je le lance »*.

**Il avait raison, et mon erreur était le sens.** `-arty` passe `country USA`, et c'est le pays qui fixe la
coalition dans DCS : la batterie est bleue. Ce n'est pas le groupe qui est du mauvais côté, c'est la
**recherche**.

## Le défaut

Le point d'entrée des alias, `veafShortcuts.lua:1780` :

```lua
-- An alias usually expands to a spawn: markers target the opposing side by default.
local spawnSide = fromMarker and veaf.getOppositeCoalition(event.coalition) or event.coalition
return veafShortcuts.executeCommand(pos, event.text, spawnSide, ...)
```

Une **seule** coalition descend toute la chaîne des modules. Elle est juste pour `veafSpawn` — un
`-shilka` posé depuis un marqueur doit être un ennemi — et fausse pour `veafGroundAI`, qui l'utilise comme
coalition du groupe **allié** à chercher dans les 250 mètres.

Un pilote bleu pose `-arty1` : la batterie apparaît en bleu, la recherche cherche du rouge, rien n'est
trouvé. Le mot *usually* du commentaire est tout le défaut.

Et le même ordre **tapé à la main** marche, parce que `veafGroundAI.onEventMarkChange` calcule la
coalition depuis celle du joueur. Deux routes, deux coalitions, pour le même module.

## Une découverte au passage

`VeafAlias:execute` appelle `veafGroundAI.executeCommand` **directement** (`:250`), sans passer par le
filtre de mot-clé de `veafCommands`. C'est ce qui explique que `-arty1` atteignait le module en 6.16.1
alors qu'un `_gc` tapé à la main n'y arrivait pas
(voir [`FIX-GC-NEVER-REACHES-THE-MODULE`](../FIX-GC-NEVER-REACHES-THE-MODULE/PRD.md)).

## Le correctif

Deux coalitions descendent la chaîne : `coalition` pour le spawn, `requesterCoalition` pour qui a demandé.
Seul l'appel à `veafGroundAI` prend la seconde ; tous les autres gardent la première. À défaut de
demandeur — le lot de démarrage de mission, le chemin distant — on retombe sur la première, donc aucun
appelant existant ne change de comportement.

Le nom est celui que `veafSpawn.executeCommand` utilise déjà pour la même idée : la notion existait, elle
ne descendait simplement pas jusqu'ici.

### Mutations

| Mutation | Résultat |
|---|---|
| le correctif annulé, retour à une seule coalition | 2 échecs |
| le spawn reçoit aussi le demandeur | 1 échec |
| le point d'entrée ne calcule plus le demandeur | 1 échec |
| le lot perd le demandeur | 1 échec |
| le report (`-alias!30`) perd le demandeur | 1 échec |

**Trois de ces cinq ne tuaient rien au départ, et toutes les trois étaient du câblage** : le point
d'entrée qui calcule la valeur, la boucle du lot qui la transmet, et le report qui la range dans sa table
d'arguments. Les premiers tests appelaient `veafShortcuts.executeCommand` **en lui donnant** le demandeur
— ils ne pouvaient donc voir ni qui le calcule, ni s'il survit à un lot ou à un délai.

Le second manque comptait doublement : **`-arty1` est un lot**, donc c'était exactement le chemin du
défaut signalé. Un test vérifie maintenant qu'il en reste un, pour que le test du lot ne passe pas un jour
pour la mauvaise raison.

C'est la cinquième et sixième occurrence du même motif dans la journée. Voir
`assert-the-wiring-not-the-handler` dans la mémoire du projet.

## Definition of done

- [x] `veafGroundAI` reçoit la coalition du demandeur, `veafSpawn` garde celle du spawn
- [x] Le point d'entrée calcule les deux, et un test l'appelle comme le répartiteur le ferait
- [x] Le demandeur survit à un lot et à un report, chacun sous test
- [x] Sans demandeur, on retombe sur la coalition de la chaîne — aucun appelant existant ne change
