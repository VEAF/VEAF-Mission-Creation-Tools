# VEAF Mission Creation Tools — 6.15.4

**Du code qui écrivait sans regarder ce qu'il effaçait.**

Cette version rassemble tout ce qui a été corrigé depuis la 6.15.0, et le fil est le même d'un bout
à l'autre : un outil qui écrit quelque part sans vérifier ce qui s'y trouvait déjà. Un réglage effacé
du `mission.yaml`, une mission dont la construction meurt sur une erreur qui ne désigne rien, un
avion créé sans une goutte de carburant — et, le plus visible de tous, un `veaf-tools.exe` qui ne
démarrait plus du tout.

Aucune de ces pannes ne se voyait dans nos tests. La deuxième moitié de cette version consiste donc
à installer les contrôles qui les rendent visibles la prochaine fois.

---

## ⚠️ À faire en premier

**Si vous avez mis à jour en 6.15.0 : mettez à jour à nouveau.** Votre `veaf-tools.exe` ne démarre
plus sur aucune commande. Il n'y a rien d'autre à faire — aucun fichier de votre côté n'a été abîmé.

**Si vous avez construit une mission en mode développeur (`--dev-mode`) entre le 17 et le 19 août :
ouvrez votre `mission.yaml` et vérifiez ce qui suivait la section `build:`.** Cette partie du fichier
pouvait être effacée à chaque construction, sans un message. Un bloc `security:` avec ses mots de
passe est le cas typique — s'il a disparu, il faut le réécrire. Cela ne concerne que le mode
développeur ; une construction normale n'a jamais touché à ce fichier.

---

## L'outil ne démarrait plus

Signalé par **Tripack**, copie d'écran à l'appui — et cette copie d'écran donnait la cause en une
lecture. Lancer `veaf-tools.exe` affichait un message d'erreur et rien d'autre, quelle que soit la
commande demandée, y compris `--help`.

Ce qui se passait : à l'intérieur de l'outil, un ensemble de composants s'est mis à se charger
**seulement quand on en a besoin**, ce qui est une bonne chose en soi. Mais le programme qui fabrique
l'exécutable devine ce qu'il doit embarquer en **lisant le code** — et du code qui ne charge rien à
l'avance ne lui annonce rien à embarquer. Onze composants sont donc restés dehors, dont celui que
l'outil réclame à la première seconde.

Toute la ligne 6.15 était concernée : ce n'est pas une commande qui échouait, c'est l'outil qui ne
s'ouvrait pas. Corrigé, et vérifié sur un exécutable reconstruit — les 25 commandes s'affichent, et
une génération de `mission.yaml` se déroule normalement.

**Ce qui change pour de bon :** avant chaque publication, la chaîne automatique **construit
l'exécutable et le lance**. Jusqu'ici, tous nos contrôles s'exécutaient depuis le code source, où ce
genre de défaut est parfaitement invisible — c'est pour cette raison qu'il est passé, ainsi que deux
autres du même genre avant lui.

---

## Le `mission.yaml` n'est plus tronqué

Le mode développeur enregistre ses réglages dans la section `build:` de votre `mission.yaml`. Pour le
faire, il coupait le fichier à cet endroit et le réécrivait — donc **tout ce que vous aviez écrit
après cette section disparaissait**. Silencieusement, à chaque construction.

La première construction est inoffensive, puisque `build:` est ajouté à la fin. Les dégâts commencent
au moment où l'on ajoute quelque chose après — ce qui est le geste naturel quand le fichier se termine
là. Mesuré : un bloc `security:`, ses empreintes de mots de passe et le commentaire final du fichier,
tous effacés en un appel.

Un second défaut a été trouvé dans le même mouvement : sous Windows, ces mêmes écritures
retournaient **toutes les lignes** du fichier au lieu de la seule section concernée, ce qui rendait
illisible la moindre comparaison entre deux versions de votre mission.

---

## Une mission aux numéros à trous ne tue plus la construction

Les fichiers de mission DCS rangent leurs éléments dans des tables numérotées. Retirez un groupe à la
main, ou passez la mission dans un outil tiers, et la numérotation devient `1, 3, 4` au lieu de
`1, 2, 3`. DCS s'en accommode ; nos outils, non : la construction mourait sur une erreur technique
désignant un sous-système qui n'avait rien à voir avec le groupe supprimé.

Les groupes, les unités, les points de route, les zones de déclenchement et leurs sommets, les
dessins de carte et les tâches imbriquées sont désormais renumérotés **à la lecture**, une fois pour
toutes. La commande `validate` vous **nomme** le trou refermé plutôt que de le réparer en silence.

Vérifié sur toutes les missions du dépôt : la renumérotation ne change pas un octet. Les
configurations d'armement sont volontairement laissées telles quelles — elles sont numérotées par
point d'emport, et les renuméroter déplacerait chaque arme sous l'aile.

---

## Édition de mission assistée : quatre trous fermés

Ces outils permettent à un assistant de modifier une mission pour vous. Quatre défauts les rendaient
plus dangereux qu'utiles.

- **Un avion créé n'avait pas de carburant.** Zéro, littéralement. Un vol créé en l'air tombait à
  l'instant où il apparaissait ; un départ au parking masquait le problème, DCS ravitaillant un avion
  garé sur les stocks du terrain. Le plein interne du type d'appareil est désormais la valeur par
  défaut, et une quantité précise peut être demandée.
- **Supprimer un groupe** est maintenant possible, et l'opération **renumérote** ce qu'elle laisse
  derrière elle — c'est cette absence qui produisait les trous décrits plus haut. Elle nomme aussi ce
  qui casserait autrement sans bruit : une zone de combat qui capture le groupe par son nom, une
  tâche d'escorte qui le désigne par son numéro, une entrée dans votre `mission.yaml`.
- **Les modifications s'appliquent à un dossier de mission**, et pas seulement à un `.miz`. C'est ce
  qui les rend durables : elles survivent à la construction suivante.
- **Une zone de combat créée est écrite au bon endroit** — dans la liste, et non sous les commentaires
  qui la suivent, où elle semblait appartenir à une autre section.

---

## Ce qu'il faut en retenir

Trois de ces quatre défauts ont été trouvés le même jour, en préparant une mission de vérification
pour un tout autre problème. Aucun n'a été trouvé par un test.

Ils forment une famille : du code qui écrit sans regarder ce qu'il détruit. Deux contrôles nouveaux
la surveillent désormais — l'un vérifie qu'un outil rendu à ses propres écritures reproduit son
fichier **à l'octet près** lorsqu'il n'a rien à changer, l'autre construit l'exécutable et le lance.
Le premier a trouvé un défaut supplémentaire dès ses deux premières utilisations.

---

## Remerciements

- **Tripack**, pour le signalement de l'exécutable qui ne démarrait plus, avec la copie d'écran qui
  contenait la réponse — et pour la constance avec laquelle il rapporte ce qu'il voit plutôt que ce
  qu'il suppose.
- **David**, pour trois défauts trouvés en préparant une mission de vérification, et pour avoir
  signalé trois fois de suite un bloc `security:` disparu avant que la cause s'avère être la
  construction, et non l'auteur de la mission.
