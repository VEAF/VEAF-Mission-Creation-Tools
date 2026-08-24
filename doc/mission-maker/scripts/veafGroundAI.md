# veafGroundAI — Piloter une batterie d'artillerie au marqueur

**Module ID:** `GROUNDAI` | **Fichier:** `veafGroundAI.lua`

---

## Objectif

Donne à un groupe de véhicules au sol un **pilote automatique** que les joueurs commandent depuis la
carte F10, avec le marqueur `_ground`. Aujourd'hui un seul type de pilote existe : l'artillerie
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

## Le marqueur `_ground` {#marker-command}

Un pilote place un marqueur sur la carte F10 et écrit son texte. Sept verbes, et **`name` est
obligatoire pour tous les sept** — c'est le nom du pilote automatique, celui que vous réutiliserez
pour lui donner ses ordres ensuite.

| Verbe | Ce qu'il fait |
|-------|---------------|
| `_ground set` *(par défaut)* | Attache un pilote automatique nommé à un groupe, et le démarre. Si le nom existe déjà, le groupe est remplacé. |
| `_ground unset` | Arrête le pilote automatique et l'oublie complètement. |
| `_ground order` | Donne un ordre au pilote automatique (voir [la syntaxe des ordres](#order-syntax)). |
| `_ground start` | Redémarre un pilote automatique arrêté. |
| `_ground stop` | L'arrête sans l'oublier — ses ordres restent en mémoire. |
| `_ground clear` | L'arrête **et** efface ses ordres. |
| `_ground status` | Affiche à l'écran ce que le pilote automatique est en train de faire. |

Écrire `_ground` seul revient à écrire `_ground set`.

### Paramètres

| Paramètre | Verbes concernés | Description |
|-----------|------------------|-------------|
| `name` | **tous** | Nom du pilote automatique. **Obligatoire** : un `_ground status, name` sans valeur est refusé, pas exécuté avec un nom vide. |
| `groupname` | `set`, `unset` | Nom exact du groupe DCS à piloter. |
| `order` | `order` | Le texte de l'ordre. |

**Si vous omettez `groupname` sur un `set`**, le module cherche le groupe allié **le plus proche du
marqueur, dans un rayon de 250 mètres**. Aucun groupe dans ce rayon : la commande ne fait rien.
Posez donc le marqueur sur la batterie, ou nommez-la.

```
_ground set, name arty-1, groupname ARTY-1
_ground status, name arty-1
_ground stop, name arty-1
```

---

## La syntaxe des ordres {#order-syntax}

Le texte passé à `order` a **sa propre syntaxe, séparée par des points-virgules** — et non par des
virgules comme le reste du marqueur. C'est le piège de ce module : un ordre écrit avec des virgules
est découpé par le marqueur avant d'atteindre l'artillerie.

| Ordre | Effet | Obus par défaut | Rayon par défaut |
|-------|-------|-----------------|------------------|
| `aim` *(par défaut)* | Tir de réglage : quelques obus pour ajuster | 2 | 10 m |
| `fire` | Tir d'efficacité | 40 | 100 m |
| `correct` | Décale le dernier point visé et retire dessus | 2 | 10 m |

| Paramètre d'ordre | Description |
|-------------------|-------------|
| `target` | Coordonnées de l'objectif. **Validées** : une chaîne que le module ne sait pas lire est ignorée, et l'ordre se plaint de ne pas avoir de cible. |
| `shells` | Nombre d'obus. Accepte une plage aléatoire, par exemple `40-80`. |
| `radius` | Dispersion du tir, en mètres. Accepte aussi une plage. |
| `correction` | Le décalage à appliquer, pour l'ordre `correct` : **trois chiffres de cap vrai puis la distance en mètres**. `09050` vaut 50 m à l'est. **Validé** : une correction illisible est refusée et annoncée, jamais devinée. |

**`fire` sans `target` tire à nouveau sur la dernière cible visée** — c'est ce qui permet d'enchaîner un
réglage puis l'efficacité sans redonner les coordonnées.

```
_ground order, name arty-1, order aim; radius 15-30; target 42 N 42 E
_ground order, name arty-1, order fire; radius 50-150; shells 40-80
```

### Le réglage du tir {#fire-adjustment}

Une batterie retient **le dernier point qu'elle a visé**, et `correct` décale ce point. C'est la boucle
de réglage classique : on tire, on observe où les obus tombent, on annonce la correction.

```
_ground order, name arty-1, order aim; target 42 N 42 E
_ground order, name arty-1, order correct; correction 09050
_ground order, name arty-1, order fire; shells 40-80
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
| `-ai_set` | `_ground set` — attache un pilote automatique au groupe le plus proche |
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
  GROUNDAI: true      # actif par défaut ; `false` retire le marqueur _ground
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
