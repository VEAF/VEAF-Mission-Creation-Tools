# veafUnits — La base des groupes et le placement au sol

**Module ID:** `UNITS` | **Fichier:** `veafUnits.lua`

---

## Objectif

Deux rôles, tous deux au service de `veafSpawn` :

1. **La base de données des groupes et des unités VEAF** — c'est elle qui fait que `-sa6` désigne une
   batterie SA-6 complète, avec ses lanceurs, son radar et son ravitaillement, plutôt qu'un seul
   véhicule.
2. **Le placement au sol** — quand un groupe apparaît, ce module décide où chaque véhicule se pose,
   en grille, autour du point demandé.

Page destinée aux **développeurs**. Un créateur de mission passe par les alias, documentés dans
[veafShortcuts](veafShortcuts.md), et un pilote par les marqueurs.

---

## Trouver un groupe ou une unité {#lookup}

`veafUnits.findGroup(alias)` et `veafUnits.findUnit(alias)` cherchent dans les deux bases par
**alias, sans tenir compte de la casse**. Un groupe porte plusieurs alias ; c'est ce qui permet à
`-sa6`, `-SA6` et aux synonymes de désigner la même chose.

Un alias introuvable renvoie `nil`, et c'est l'appelant qui décide du message — le module ne parle pas
au joueur.

---

## Le placement en grille {#placement}

`veafUnits.placeGroup(group, spawnPoint, spacing, hdg, hasDest)` répartit les unités autour du point
d'apparition.

- **Sans disposition déclarée, la forme par défaut est un carré** : le côté vaut
  `ceil(sqrt(nombre d'unités))`. Un groupe de 10 véhicules tient donc dans une grille 4×4 partiellement
  remplie.
- **Sans cap donné, le groupe est orienté au nord** (`hdg = 0`).
- `spacing` écarte les unités les unes des autres ; il est exprimé en multiples de la taille de
  l'unité, pas en mètres.

`veafUnits.checkPositionForUnit` refuse une position qui ne convient pas à l'unité — c'est ce qui
empêche un char d'apparaître dans l'eau. Depuis `FEAT-SCENERY-AWARE-SPAWN`, la recherche d'un point
correct passe par `veaf.findSpawnPoint`, qui sait aussi éviter les villages et les forêts.

---

## Le correctif de pathfinding {#pathfinding-fix}

`veafUnits.removePathfindingFixUnit(groupName)` retire une unité ajoutée artificiellement à un groupe
pour débloquer le calcul d'itinéraire de DCS. Un groupe qui apparaît avec une destination reçoit ce
correctif, puis l'unité est retirée après un délai.

---

## Compter ce qu'un groupe contient {#counting}

`veafUnits.countInfantryAndVehicles(groupname)` renvoie le nombre de fantassins et de véhicules d'un
groupe. C'est ce qui alimente les rapports d'état, notamment ceux des zones de combat.

---

## Configuration `mission.yaml`

Aucune. Le module est de l'infrastructure : il se charge toujours.

---

## Voir aussi

- [veafShortcuts](veafShortcuts.md) — les alias que ces bases rendent possibles
- [veafSpawn](veafSpawn.md) — le module qui fait apparaître les groupes
- [Référence de l'API Lua](../../LUA_API_REFERENCE.md) — la signature détaillée de chaque fonction
