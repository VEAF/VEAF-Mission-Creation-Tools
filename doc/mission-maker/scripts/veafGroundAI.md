# veafGroundAI — L'artillerie au marqueur et les convois sous le feu

**Module ID:** `GROUNDAI` | **Fichier:** `veafGroundAI.lua`

---

## Objectif

Donne à un groupe de véhicules au sol un **pilote automatique** que les joueurs commandent depuis la
carte F10, avec le marqueur `_gc`. Deux types de pilote existent :

- **l'artillerie** (`ArtilleryUnitHandler`), à qui on ordonne de tirer sur des coordonnées — quelques obus pour se régler, puis un tir d'efficacité ;
- **le convoi** (`ConvoyUnitHandler`), qui se débrouille seul : il guette l'ennemi devant lui, se scinde quand il le voit, appelle l'appui aérien et se replie à couvert ([le convoi sous le feu](#convoy)).

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

## Le convoi sous le feu {#convoy}

Livré à lui-même, un convoi DCS traverse une embuscade à pleine vitesse sans tirer un coup, et meurt.
Mesuré le 2026-10-08 : quatre véhicules détruits sur quatre, aucune riposte ; et quand on lui donne une nouvelle route en plein feu, seul le véhicule de tête obéit, le reste de la colonne reste planté.
Le pilote automatique de convoi fait le travail à sa place, **sans personne aux commandes**.

### Ce qu'il fait tout seul {#convoy-behaviour}

1. **Il guette.** Toutes les 30 s, il cherche les véhicules ennemis à moins de 5 km (plus une minute de route à sa vitesse). Tant qu'il y en a, il vérifie toutes les 3 s s'il les voit — le relief entre eux compte, la végétation non (voir les [limites](#limitations)).
2. **Il réagit au premier qui compte** : un ennemi en vue à moins de 3 km, ou le premier tir reçu (artillerie, avion, embuscade invisible).
3. **Il se scinde.** Les véhicules non armés (camions…) partent **immédiatement** se replier, dans leur propre groupe, nommé `<convoi> unarmed`. Les véhicules armés restent dans le groupe du convoi, qui garde son nom.
4. **Les armés combattent ou se replient.** Chaque véhicule a une valeur de combat : char 4, véhicule de combat d'infanterie 3, blindé de transport, AAA ou autre véhicule armé 1, non armé 0. Si les armés valent au moins 1,5 fois les ennemis en vue, ils **vont au contact** jusqu'à 900 m de l'ennemi le plus proche, alarme rouge, feu à volonté ; sinon ils se replient à leur tour. Un avion ou un tir venu de plus de 3 km ne se combat pas : on se replie.
5. **Il appelle à l'aide**, à sa coalition, sous la forme d'un appel *troops in contact* : sa position (coordonnées et MGRS), le nombre et le type d'ennemis, leur cap et leur distance. Un **fumigène rouge** marque l'ennemi le plus proche, un **vert** le convoi, renouvelés toutes les 5 minutes tant que le contact dure. Si la mission sait parler ([SRS configuré](#srs-voice)), le même appel passe en voix sur 243 et 121,5 MHz AM.
6. **Il se replie à couvert** : vers le lieu ami le plus proche (une zone de campagne de son camp, un de ses aérodromes), en passant par un point que le relief ou une ville cache à l'ennemi ; s'il n'y en a aucun, le plus court chemin hors de portée.
7. **Il tient.** Une minute sans rien voir ni rien recevoir : il le dit, s'arrête et attend un ordre — il ne repart pas tout seul dans la même embuscade.

Un convoi rouge fait exactement la même chose, du côté rouge.

### Quels groupes {#convoy-groups}

- **Chaque convoi apparu par `_spawn convoy`**, automatiquement. Son nom est celui que le spawn lui donne (`[b]-Convoy-3`…) ; un fragment suffit dans `_gc`, comme pour `groupname`.
  Attention : `-convoy` fait apparaître un convoi **rouge** par défaut — une cible. Pour un convoi ami, ajoutez `side blue` : `-convoy, dest ALPHA, side blue`.
- Un groupe de l'éditeur de missions, listé dans `mission.yaml` ([plus bas](#configuration-missionyaml)).
- N'importe quel groupe, en jeu : `_gc <nom>, convoy`, le marqueur posé sur le groupe (ou avec `groupname`).

### Les ordres {#convoy-orders}

| Ce que vous écrivez | Ce que ça fait |
|---|---|
| `_gc convoy-3, retreat` | repli par la route vers le lieu ami le plus proche |
| `_gc convoy-3, retreat KOBULETI` | repli vers ce point nommé, ou ces coordonnées |
| `_gc convoy-3, hold` | arrêt sur place, des deux groupes |
| `_gc convoy-3, resume` | repart : les combattants reprennent la route, les non armés les rejoignent, et le convoi se reforme en un seul groupe à moins de 300 m |
| `_gc convoy-3, status` | ce que fait le convoi (en route, en alerte, au combat, en repli, à l'arrêt…) |
| `_gc ravito, convoy, groupname Ravitaillement` | confie le groupe `Ravitaillement` au pilote de convoi, sous le nom `ravito` |

Ce sont aussi ces marqueurs qu'un maître du jeu envoie pour diriger un convoi.

### Faire parler la mission {#srs-voice}

La voix passe par SRS (`DCS-SR-ExternalAudio.exe`). VEAF lit sa configuration dans `Saved Games\DCS\DCS-SimpleRadio-Standalone\SRS_for_scripting_config.lua`, sur la machine qui héberge la mission ; sans ce fichier, l'appel part en texte seulement :

```lua
if not SERVER_CONFIG then SERVER_CONFIG = {} end
SERVER_CONFIG.SRS_DIRECTORY = "C:\\Program Files\\DCS-SimpleRadio-Standalone\\ExternalAudio"
SERVER_CONFIG.SRS_PORT = 5002
SERVER_CONFIG.SRS_EXECUTABLE = "DCS-SR-ExternalAudio.exe"
if not STTS then STTS = {} end
STTS.DIRECTORY = SERVER_CONFIG.SRS_DIRECTORY
STTS.SRS_PORT = SERVER_CONFIG.SRS_PORT
STTS.EXECUTABLE = SERVER_CONFIG.SRS_EXECUTABLE
```

`SRS_DIRECTORY` est le dossier qui contient `DCS-SR-ExternalAudio.exe` (un sous-dossier `ExternalAudio` sur les versions récentes de SRS), `SRS_PORT` le port du serveur SRS.
Il faut aussi que la mission ait accès à `os` : un `MissionScripting.lua` qui le retire, comme le fait celui d'origine de DCS, rend la mission muette.

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

Le module s'active et se désactive comme les autres :

```yaml
modules:
  GROUNDAI: true      # actif par défaut ; `false` retire le marqueur _gc et la surveillance des convois
```

Sa seule option est la liste des groupes de l'éditeur à surveiller comme des convois — les `_spawn convoy` le sont toujours, sans rien déclarer :

```yaml
modules:
  GROUNDAI:
    enabled: true
    convoys:
      - Ravitaillement Nord
      - Convoi Kutaisi
```

---

## Limites connues {#limitations}

- **Deux types de pilote automatique existent** : l'artillerie et le convoi. Le module est bâti pour en accueillir
  d'autres (`veafGroundAI.add` / `.remove` / `.get` prennent n'importe quel gestionnaire nommé).
- **La veille du convoi ne voit pas la végétation.** `land.isVisible` ne tient compte que du relief : le convoi peut juger « en vue » un ennemi que les arbres cachent à l'IA de DCS. C'est pourquoi ses armés vont au contact au lieu de s'arrêter : arrêtés à 1,9 km d'un ennemi « en vue », deux Bradley n'ont pas tiré un coup en deux minutes (mesuré le 2026-10-08).
- **Les arbres ne servent pas de couvert au repli** : `world.searchObjects` ne les trouve pas. Seuls le relief et les villes cachent le point de repli.
- **Le fumigène n'aveugle pas l'IA de DCS** (mesuré le 2026-10-08) : il marque, pour les pilotes. Le convoi ne pose donc pas de rideau de fumée.
- **Un véhicule détaché ou regroupé repart neuf** : DCS ne permet pas de recréer une unité avec ses dégâts. La veille scinde presque toujours le convoi avant le premier coup reçu.
- **Le rayon de recherche de 250 mètres n'est pas configurable.**
- Les ordres passent par la carte F10 uniquement : **ce module n'a pas de menu radio**.
- **La correction n'a pas d'observateur automatique** : c'est le pilote qui regarde où les obus tombent et qui annonce le décalage. Le module ne mesure pas l'écart
  lui-même.

---

## Voir aussi

- [veafShortcuts](veafShortcuts.md) — la liste complète des alias, dont `-ai_set` et la famille `-arty*`
- [veafSecurity](veafSecurity.md) — ce que veut dire `KNOWN_PILOT`, et comment un pilote non inscrit passe quand même
- [veafSpawn](veafSpawn.md) — faire apparaître la batterie que ce module va piloter
