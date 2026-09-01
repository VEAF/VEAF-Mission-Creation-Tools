# VEAF Mission Creation Tools — 6.18.0

**MiST s'en va, et vos missions s'allègent de 336 Ko.**

Depuis toujours, chaque mission VEAF embarquait MiST — la bibliothèque historique de scripting DCS —
parce que nos scripts s'appuyaient dessus. Ils ne l'appellent plus du tout. CTLD s'en était détaché de
lui-même en v2, CSAR et Skynet ont été portés, le script Hercules a été retiré. Les dernières lignes
qui la mentionnaient encore étaient du code mort.

Ce que VEAF lui empruntait, VEAF le fait maintenant lui-même : la planification des tâches, les
mathématiques et les vecteurs, la géométrie, l'écriture des coordonnées, la création des groupes et
des objets statiques, la lecture et l'écriture des routes, et l'inventaire de ce que contient la
mission.

L'autre nouveauté de cette version est un outil : **`veaf-logs`**, un lecteur de journaux DCS qui
connaît nos scripts et masque le reste.

---

## ⚠️ À lire avant de mettre à jour

Trois changements modifient le comportement de missions déjà en service.

### 1. Vos zones de combat vont spawner moins

`#spawnchance` ne pouvait pas refuser un spawn. La zone tirait un nombre au hasard par élément et
recommençait jusqu'à dix fois, en **forçant** le tirage à la dernière tentative. Dans le cas courant —
un élément seul, `#spawncount` valant 1 par défaut — cela donnait neuf tirages au hasard suivis d'un
tirage garanti : l'élément spawnait toujours. Même `#spawnchance=0` spawnait.

Autrement dit, `#spawnchance` changeait **quand**, jamais **si**. L'embuscade à quatre MANPADS de la
documentation promettait « environ deux actifs » et en livrait quatre, à chaque fois.

La probabilité est désormais respectée telle qu'elle est écrite : un tirage par élément, et
`#spawnchance=0` ne spawne jamais. **Une mission en service qui utilise `#spawnchance` produira donc
moins d'ennemis qu'avant** — c'est-à-dire ce que son auteur avait demandé.

Les tentatives multiples sont conservées lorsque vous avez **écrit** un `#spawncount` : la promesse
d'un nombre est tenue, `#spawncount=2` sur quatre éléments groupés livre bien exactement deux
éléments, même à 50 % chacun.

### 2. Un décalage de vague ou de QRA se déplace là où son nom le dit

Le préfixe `[latDelta,lonDelta]` et le réglage `setRespawnDefaultOffset(latitude, longitude)`
appliquaient leurs deux nombres **aux mauvais axes** : le premier déplaçait vers l'est, le second vers
le sud, et le nord était soustrait en plus — un décalage « latitude » positif éloignait donc du pôle.

**Cela déplace les missions existantes.** Une mission qui pose un décalage non nul spawnera ailleurs,
jusqu'à deux fois la valeur du décalage. Un décalage réglé à l'œil contre l'ancien comportement doit
être réécrit tel qu'il se lit. Une mission qui n'en pose aucun n'est pas concernée : le défaut livré
est `[0, 0]`.

### 3. MiST n'est plus injecté — sauf si votre script l'appelle

Vos propres scripts peuvent encore appeler MiST. Un tel appel aurait échoué en vol avec
`attempt to index nil (global 'mist')`, pas au build. **Le build regarde donc** : il lit vos
`src/scripts/*.lua`, et injecte MiST dès qu'il y trouve un appel, en nommant le fichier qui l'a
demandé. Les commentaires et les chaînes de caractères ne comptent pas.

`convert-v5` pose la même question, ce qui est l'essentiel pour migrer : une mission v5 embarquait
MiST dans tous les cas, donc sa présence ne prouve rien — mais une mission convertie dont le
HoundElint appelle `mist.DBs.humansByName` la conserve.

`MIST: true` reste disponible pour ce qu'une analyse ne peut pas voir : un script qui en charge un
autre, ou un accès par `_G["mist"]`. En revanche `MIST: false` **ne l'emporte pas** sur la détection —
l'honorer casserait la mission en vol pour respecter une ligne de configuration.

---

## `veaf-logs` — lire un journal DCS

Un journal DCS enterre ce qui compte sous du bruit sur lequel personne ne peut agir. Ce lecteur
connaît nos scripts et masque le reste : sur un `dcs.log` courant, il ramène 416 lignes sévères à
**69**.

Trois choses qu'un lecteur de journaux généraliste ne peut structurellement pas faire :

- **une trace d'appel reste avec son erreur** — filtrer sur les erreurs ne cache plus le
  `stack traceback` qui les explique ;
- **le niveau affiché est le vrai.** DCS journalise tout le Lua en `INFO SCRIPTING`, donc un
  avertissement `VEAF|W|` arrive étiqueté INFO. L'outil le lit dans le préfixe, et filtrer sur
  WARNING fait enfin apparaître les avertissements de VEAF, CTLD et CSAR ;
- **les erreurs inoffensives d'ED sont masquées par famille** — modèles de dégâts corrompus, masses
  d'emport négatives, voies de circulation manquantes — chacune activable, avec le compte de ce qui
  est caché, pour que le filtre ne soit jamais silencieux.

Chaque catégorie dispose d'un troisième état entre « affiché » et « masqué » : le **contexte**, qui la
conserve autour des lignes qui comptent, à la manière de `grep -C`. Un jeu de filtres complet
s'enregistre en **profil** ; trois sont livrés avec l'outil.

Il lit un journal serveur de **119 Mo en 8,6 secondes avec 37 Mo de mémoire**, en indexant en tâche de
fond pendant que vous lisez déjà les premières lignes. Il ne garde jamais le journal ouvert — sous
Windows, cela empêcherait DCS de faire tourner le sien au lancement.

Livré comme exécutable séparé, `veaf-logs.exe`. Sa dépendance Qt est optionnelle, donc
`veaf-tools.exe` ne grossit pas. Documenté dans `doc/mission-maker/LOGS.md`.

---

## Ce qui se pose au sol se pose enfin où vous l'avez demandé

- **L'escorte d'une FARP pouvait être garée à travers un bâtiment, ou dans un bois.** Elle regarde
  maintenant le terrain avant de se poser, et une escorte placée sur un terrain dégagé ne s'en va
  plus.
- **Deux spawns au sol posaient leurs unités sans regarder le terrain.**
- **Un avion ne peut plus être spawné dans le décor** : le contrôle censé l'en empêcher lisait une
  longitude à la place d'une altitude.
- **Une FARP, une FOB et une balise CTLD** sont désormais documentées comme allant exactement là où
  vous les posez.
- **Six endroits posaient à DCS la même question sur le sol** ; un seul le fait maintenant — et l'un
  des six se trompait.

## Les coordonnées

- Une coordonnée pouvait afficher `42 60'` au lieu de `43 00'`.
- Une coordonnée valant exactement zéro était lue Sud et Ouest.
- **Un guillemet dans une valeur de `mission.yaml` ne casse plus toute la mission.** Une coordonnée
  écrite comme DCS l'affiche rendait le fichier de configuration généré illisible par Lua — et donc
  **aucun** module VEAF ne s'initialisait, sans le moindre message. Le build refuse maintenant de
  livrer un fichier qui ne se lit pas, et dit à quelle ligne.

## Spawns aériens et patrouilles

- **Les patrouilles répondent à nouveau sur tous les modèles.** Plus de la moitié des modèles d'avions
  livrés — dont tous les MiG-29 — étaient introuvables, parce que la recherche n'entrait que dans les
  coalitions rouge et bleue et que ces modèles sont neutres. 61 modèles sur 117 étaient invisibles.
- **Spawner deux fois le même groupe ne supprime plus le premier.** Le clone gardait les noms d'unités
  du modèle, et DCS supprime ce qu'il connaît déjà avant de le recréer. Cela touchait les patrouilles,
  les AFAC et les missions de combat.
- **Une patrouille engage à nouveau le combat.** Sa liste de cibles mémorisait l'avion qui détecte au
  lieu de la cible détectée : le contrôle de fraîcheur demandait donc si la patrouille vole encore, et
  jetait ses cibles à chaque passage après avoir déjà levé l'interdiction de tir air-air. Les
  patrouilles volaient donc sans rien à engager.
- **Une vague ou une QRA lancée par une commande VEAF arrive dans sa propre zone**, et non sur le
  méridien du théâtre.
- **Poser un groupe où vous voulez est devenu une phrase**, au lieu d'une table de clés à retenir.

## Escortes et transport

- **Un asset qui réapparaît ramène son escorte avec lui.** Elle rentrait à la maison si sa tâche
  `Escort` n'était pas posée sur le tout dernier point de route.
- **Téléporter un groupe apparu en cours de mission** échouait sur « country not found ».
- **CSAR ne démarrait dans aucune mission**, et aucun test ne pouvait le voir.

## Aérodromes

- **Sept aérodromes refusaient tous les avions** que vous tentiez d'y garer.
- **Les aérodromes n'étaient plus approvisionnés** en avions que leur terrain ne peut pas accueillir.

## Outillage et documentation

- L'exécutable propose enfin l'arborescence de commandes par thème que la documentation décrit.
- `validate` nomme désormais **chaque** pays qu'une coalition a laissé sans affectation.
- Une zone de combat dit quels groupes elle a laissés de côté, et ne perd plus un `#spawncount`
  déclaré.
- `convert-other --update` faisait le travail sans en rendre compte.
- `extract-aircraft-groups --merge` enrichit un catalogue au lieu de le recommencer.
- `prepare --template minimal` ne livre plus cinq scripts communautaires dont vous n'avez pas voulu.
- **Tous les exemples de commande de la documentation s'exécutent tels quels dans PowerShell.**
- La documentation enseigne VMCT au lieu de se contenter de le documenter, et ne dit plus que MiST
  est obligatoire.

## Retiré

- Le script communautaire **Hercules Cargo**.
- L'injection de **MiST** — voir l'encadré ci-dessus.
