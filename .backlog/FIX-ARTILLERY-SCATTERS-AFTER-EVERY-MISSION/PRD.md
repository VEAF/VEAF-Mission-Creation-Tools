# FIX-ARTILLERY-SCATTERS-AFTER-EVERY-MISSION — la batterie quittait sa position entre deux ordres

Status: ✅ done

Trouvé en jeu le 2026-08-25. David : *« j'ai l'impression que "_gc arty-1, fire, shells 40-80" ne
fonctionne pas ; les canons se sont déplacés et ne tirent pas. Pourtant ils ont bien fait leur tir d'essai
(avant que je donne la commande "fire", et qu'ils se déplacent) »*.

Sa description portait le diagnostic : **les canons se sont déplacés**, et le tir de réglage avait
fonctionné. Le code marchait donc ; c'est ce qu'il demandait à DCS qui était faux.

## Le défaut

L'ordre de tir passait `counterbattaryRadius = 500`, codé en dur et jamais expliqué. Le schéma de l'API
DCS décrit ce champ ainsi :

> *le rayon en mètres, depuis le chef de groupe, dans lequel le groupe se déplacera dans des directions
> aléatoires **après avoir terminé** la tâche `fireAtPoint`*

C'est de l'évitement de contre-batterie. Sur un tir isolé, c'est réaliste et sans conséquence. Sur une
**boucle de réglage**, c'est destructeur :

1. le tir de réglage part ;
2. la tâche se termine, les canons roulent dans un rayon de 500 m ;
3. l'ordre d'efficacité arrive sur un groupe **en mouvement** — et une pièce d'artillerie ne tire pas en
   roulant : elle doit finir son déplacement et se remettre en batterie.

Le paramètre valait donc exactement le contraire de ce que la fonctionnalité livrée la veille demandait.

**La correction, elle, restait juste** : elle porte sur la **cible**, pas sur la position des canons. Ce
n'était pas le calcul qui était en cause, seulement le tir empêché.

## Ce que personne ne regardait

**Aucun test ne couvrait la tâche remise à DCS.** Ni le rayon de dispersion, ni les axes, ni le drapeau
`expendQtyEnabled` sans lequel DCS ignore le nombre d'obus. Le `500` était là depuis toujours, sans une
ligne pour le justifier.

Six tests regardent maintenant la table exacte poussée au contrôleur, ce qui est le seul endroit d'où le
défaut était visible.

### Mutations

| Mutation | Résultat |
|---|---|
| la dispersion revient à 500 *(le bug d'origine)* | 1 échec |
| le nord et l'est échangés dans la tâche | 1 échec |
| `expendQtyEnabled` mis à faux | 1 échec |
| le rayon de zone ignoré | 1 échec |

## Un mock qui mentait, corrigé au passage

`coord.LLtoMGRS` rendait une table **sans `UTMZone`**, alors que le vrai DCS le fournit toujours. Tout code
qui construit une grille lisible fait `grid.UTMZone .. " " .. grid.MGRSDigraph .. …` et mourait sur une
concaténation de nil dès qu'un test atteignait ce chemin. Un mock incomplet ne fait pas échouer le code qui
le lit : il le fait planter ailleurs, ce qui coûte le temps de comprendre que le défaut n'est pas là.

## Definition of done

- [x] La batterie reste en place après une mission de tir
- [x] La tâche remise à DCS est sous test — axes, obus, rayon, drapeau
- [x] Le zéro porte sa raison dans le code, pour qu'on ne le remette pas à 500 en croyant bien faire
- [x] Le mock MGRS rend la forme que DCS rend
