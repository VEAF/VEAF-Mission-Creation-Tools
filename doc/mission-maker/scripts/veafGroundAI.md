# veafGroundAI — Piloter une batterie d'artillerie au marqueur

**Module ID:** `GROUNDAI` | **Fichier:** `veafGroundAI.lua`

---

## Objectif

Donne à un groupe de véhicules au sol un **pilote automatique** que les joueurs commandent depuis la
carte F10, avec le marqueur `_gc`. Aujourd'hui un seul type de pilote existe : l'artillerie
(`ArtilleryUnitHandler`), à qui on ordonne de tirer sur des coordonnées — quelques obus pour se
régler, puis un tir d'efficacité.

Le module est **actif par défaut** (`veaf.registerModule(..., { enable = true }, 190)`), et ses
commandes sont réservées aux **pilotes connus du serveur** : `KNOWN_PILOT`, soit tout pilote inscrit
dans `veaf-pilots.txt`. Un pilote non inscrit doit fournir le mot de passe correspondant.

---

## Dépendances

- `veafCommands` — c'est lui qui reçoit le marqueur et applique le contrôle de sécurité
- `veafSecurity` — palier `KNOWN_PILOT`
- `veafShortcuts` — les alias `-ai_set` et la famille `-arty*` (facultatif mais c'est l'usage courant)

---

## Le marqueur `_gc` {#marker-command}

`_gc`, pour *ground commander*. Un pilote place un marqueur sur la carte F10 et écrit :

```
_gc <nom>, <verbe> <valeur>, <paramètre valeur>, ...
```

**Le destinataire d'abord**, comme à la radio. Le `<nom>` est celui que vous donnez au pilote
automatique — vous le choisissez, et vous le réutilisez pour tous ses ordres.

| Ce que vous écrivez | Ce que ça fait |
|---|---|
| `_gc arty-1` *(marqueur sur la batterie)* | crée le pilote automatique `arty-1` et le démarre |
| `_gc arty-1, groupname ARTY-1` | idem, en nommant le groupe DCS au lieu de le chercher |
| `_gc mabatterie, groupname arty-1` | idem, sur un groupe apparu par une commande VEAF |
| `_gc arty-1, aim 37T GG 12345 12345` | tir de réglage sur cette position |
| `_gc arty-1, correction 09050` | décale le dernier point visé et retire ([le réglage du tir](#fire-adjustment)) |
| `_gc arty-1, fire` | tir d'efficacité au dernier point visé |
| `_gc arty-1, fire 37T GG 12345 12345, shells 40-80` | tir d'efficacité sur une position donnée |
| `_gc arty-1, status` | affiche ce que la batterie est en train de faire |
| `_gc arty-1, stop` | l'arrête, ses ordres restent en mémoire |
| `_gc arty-1, clear` | l'arrête **et** efface ses ordres |
| `_gc arty-1, start` | redémarre un pilote automatique arrêté |
| `_gc arty-1, unset` | l'arrête et l'oublie complètement |

**Écrire `_gc <nom>` seul revient à écrire `_gc <nom>, set`.**

### Les paramètres

| Paramètre | Description |
|-----------|-------------|
| `groupname` | Nom du groupe DCS à piloter. **Un fragment suffit** : le groupe que `-arty, unitname arty-1` fait apparaître s'appelle en réalité `[b]-arty-1#7`, et `groupname arty-1` le trouve. Si plusieurs groupes correspondent, la commande est refusée et les noms trouvés vous sont dits — plutôt que d'en choisir un au hasard. Sur un `set`, si vous omettez le paramètre, le module cherche le groupe allié **le plus proche du marqueur, dans un rayon de 250 mètres** — et vous le dit s'il n'en trouve aucun. |
| `target` | Les coordonnées, si vous préférez les écrire séparément plutôt qu'après `aim` ou `fire` ([les formats acceptés](#coordinate-formats)). |
| `shells` | Nombre d'obus. Accepte une plage aléatoire, par exemple `40-80`. |
| `radius` | Dispersion du tir, en mètres. Accepte aussi une plage. |

`correct` s'écrit aussi `correction` : les deux marchent, pour ne pas avoir à s'en souvenir.

```
_gc arty-1
_gc arty-1, radius 15-30, aim 37T GG 12345 12345
_gc arty-1, correction 09050
_gc arty-1, fire, shells 40-80, radius 50-150
```

> **L'ancienne syntaxe marche encore.** `_ground order, name arty-1, order aim; target …` reste acceptée
> pour ne casser aucune mission existante, mais elle n'est plus documentée : elle demandait un
> point-virgule là où tout le reste de VEAF utilise la virgule, et c'était son seul piège.

---

## Les trois ordres {#order-syntax}

| Ordre | Effet | Obus par défaut | Rayon par défaut |
|-------|-------|-----------------|------------------|
| `aim` | Tir de réglage : quelques obus pour ajuster | 2 | 10 m |
| `fire` | Tir d'efficacité | 40 | 100 m |
| `correct` *(ou `correction`)* | Décale le dernier point visé et retire dessus | 2 | 10 m |

`aim` et `fire` prennent les coordonnées **juste après le mot** : `aim 37T GG 12345 12345`. `correct`
prend son décalage de la même façon : `correction 09050`.

**`fire` sans coordonnées tire à nouveau sur la dernière cible visée** — c'est ce qui permet d'enchaîner
un réglage puis l'efficacité sans redonner la position.

Les deux valeurs sont **validées à la lecture** : une position ou un décalage que le module ne sait pas
lire est refusé et annoncé, jamais deviné. Un chiffre qu'un canon exécute ne se devine pas.

```
_gc arty-1, radius 15-30, aim 37T GG 12345 12345
_gc arty-1, correction 09050
_gc arty-1, fire, shells 40-80, radius 50-150
```

### Les formats de coordonnées acceptés {#coordinate-formats}

Un `target` accepte toutes ces formes. Elles valent **partout où VEAF lit une coordonnée** — zones
AirWaves, points nommés, QRA, alias — parce qu'un seul lecteur les traite toutes.

| Ce que vous écrivez | Ce que c'est | Précision |
|---|---|---|
| `37T GG 12345 12345` | MGRS **tel que DCS l'affiche** | 1 m |
| `37TGG12345678` | le même, sans les espaces | 10 m |
| `u37TGG123456` | l'ancienne syntaxe VEAF, toujours valable | 100 m |
| `N42:30:15E041:45:30` | degrés, minutes, secondes | ~30 m |
| `N42 30 15 E041 45 30` | les mêmes, séparés par des espaces | ~30 m |
| `N42°30'15"E041°45'30"` | les mêmes, avec les symboles | ~30 m |
| `N42:30.5E041:45.5` | degrés et minutes décimales | ~2 m |
| `N42.50416E041.75833` | degrés décimaux | ~1 m |
| `N42E041` | degrés entiers | ~100 km |

**Le nombre de chiffres MGRS est la précision** : deux chiffres de chaque côté valent 10 km, cinq valent
le mètre. Un nombre **impair** de chiffres est refusé plutôt que deviné — c'est une faute de frappe, et
la couper en deux produirait une position que personne n'a demandée.

`S` et `W` donnent les valeurs négatives. La casse est libre.

**Le conseil pratique** : lisez les coordonnées sur votre propre écran et recopiez-les telles quelles. Le
format MGRS que DCS affiche est accepté sans retouche, et c'est le moins susceptible d'être mal recopié.

### Le réglage du tir {#fire-adjustment}

Une batterie retient **le dernier point qu'elle a visé**, et `correct` décale ce point. C'est la boucle
de réglage classique : on tire, on observe où les obus tombent, on annonce la correction.

```
_gc arty-1, aim 37T GG 12345 12345
_gc arty-1, correction 09050
_gc arty-1, fire, shells 40-80
```

Le cap s'écrit **toujours sur trois chiffres**, parce que `090` et `90` seraient la même chaîne une fois
la distance collée derrière : `09050` c'est 50 m à l'est, `9050` serait lu comme un cap de 905 et refusé.

Deux corrections se **cumulent** : deux fois `09050`, et le point visé a bougé de 100 m vers l'est.
`fire` sans cible, ensuite, tire à l'endroit corrigé — c'est le même point visé pour les deux ordres.

La correction est refusée, et le refus est annoncé au pilote, dans deux cas : quand elle est illisible
(le message rappelle alors la forme attendue), et quand la batterie n'a **aucun tir en cours** à corriger
— tirer sur le seul décalage mettrait les obus là où la batterie se trouve.

---

## Les alias fournis {#aliases}

`veafShortcuts` livre des raccourcis prêts à l'emploi, et c'est par eux que la plupart des pilotes
utilisent ce module :

| Alias | Ce qu'il fait |
|-------|---------------|
| `-ai_set` | `_gc` — attache un pilote automatique au groupe le plus proche ; écrivez son nom derrière |
| `-arty1`, `-arty2`, `-arty3` | Fait apparaître une batterie **et** lui attache son pilote automatique nommé `arty-1`, `arty-2`, `arty-3` |
| `-arty1_aim`, `-arty2_aim`, `-arty3_aim` | Ordre de réglage à la batterie correspondante |
| `-arty1_fire`, `-arty2_fire`, `-arty3_fire` | Ordre d'efficacité à la batterie correspondante |

Ces alias de tir **se terminent volontairement sur `target` sans valeur** : vous écrivez les
coordonnées juste après, et elles complètent l'ordre.

```
-arty1                          # la batterie apparaît et son pilote automatique démarre
-arty1_aim 42 N 42 E            # elle se règle sur ces coordonnées
-arty1_fire                     # puis tire pour de bon, sur la même cible
```

---

## Configuration `mission.yaml` {#configuration-missionyaml}

Le module n'a **aucune option de configuration**. Il s'active et se désactive comme les autres :

```yaml
modules:
  GROUNDAI: true      # actif par défaut ; `false` retire le marqueur _gc
```

---

## Limites connues {#limitations}

- **Un seul type de pilote automatique existe** : l'artillerie. Le module est bâti pour en accueillir
  d'autres (`veafGroundAI.add` / `.remove` / `.get` prennent n'importe quel gestionnaire nommé), mais
  aucun autre n'est livré.
- **Le rayon de recherche de 250 mètres n'est pas configurable.**
- Les ordres passent par la carte F10 uniquement : **ce module n'a pas de menu radio**.
- **La correction n'a pas d'observateur automatique** : c'est le pilote qui regarde où les obus tombent et qui annonce le décalage. Le module ne mesure pas l'écart
  lui-même.

---

## Voir aussi

- [veafShortcuts](veafShortcuts.md) — la liste complète des alias, dont `-ai_set` et la famille `-arty*`
- [veafSecurity](veafSecurity.md) — ce que veut dire `KNOWN_PILOT`, et comment un pilote non inscrit passe quand même
- [veafSpawn](veafSpawn.md) — faire apparaître la batterie que ce module va piloter
