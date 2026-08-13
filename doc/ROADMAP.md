# Feuille de route

**La feuille de route vit dans le dépôt, pas ici** :
[`ROADMAP.md`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/ROADMAP.md) donne
l'ordre d'exécution des lots ouverts, et
[`.backlog/`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/tree/develop/.backlog) le
périmètre et l'état de chacun. Ces deux sources sont tenues à jour en même temps que le code ; cette
page ne l'était pas, et affirmait encore que la branche `master` portait une release v5 alors qu'elle
est passée en v6 le 18 juillet 2026.

Ce qui suit est donc volontairement court : les trois axes de fond, sans dates ni statuts, pour
situer le projet. Aucune date de livraison n'est engagée.

## Les trois axes

**Campagne persistante.** Un module de persistance qui sauvegarde l'état d'une mission entre deux
lancements — les unités DCS comme les machines à états VEAF (missions CAS, zones de combat, QRA) —
puis, dessus, de la génération de campagne dynamique et persistante bâtie uniquement sur les outils
VEAF. Chemin de dépendance : retirer MiST, puis la persistance, puis la campagne.

**Outillage assisté par IA.** Décrire une mission en français ou en anglais et obtenir son
`mission.yaml` avec ses spawns et ses zones — au *design-time*, avec l'outillage IA du créateur de
mission plutôt que sur une infrastructure VEAF. Un serveur MCP livre déjà l'édition d'un `.miz` et la
mutation de ce qu'il contient. Plus loin sur le même axe, un maître du jeu qui improvise une campagne
en direct pendant que le joueur vole.

**Le pont DCS.** Finir l'intégration de `veaf-dcs-bridge`, la liaison entre un DCS en cours
d'exécution et un programme extérieur. C'est la brique commune de la persistance, du maître du jeu et
d'un tableau de bord temps réel dans le navigateur.

## Ce qui est déjà arrivé

Le cycle v6 est complet et publié ; `master` porte la v6. Les changements notables de chaque version
sont dans le
[journal des modifications](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/CHANGELOG.md).
