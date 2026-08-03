# veafAssist — Checklists guidées

**Module ID:** `ASSIST` | **Fichier:** `veafAssist.lua`

---

## Objectif

Guide un pilote pas à pas dans une procédure. À chaque étape, le module **encadre dans le cockpit**
la commande à actionner, **coche la ligne** dès que cette commande atteint la bonne position — ou dès
que le pilote confirme lui-même —, et passe à la suivante. La checklist complète reste affichée à
l'écran sous forme d'image.

Le module ne connaît aucun appareil : les checklists sont des **données**, écrites en YAML et
converties par la construction de la mission.

Un seul appareil est livré avec une checklist : le **F-16C** (démarrage moteur).

---

## Pour le pilote {#for-pilots}

Menu radio F10 → `Assistance`. Une entrée par checklist applicable à l'appareil : si votre appareil
n'en a aucune, aucune entrée n'apparaît.

Une fois la checklist lancée, le menu propose :

| Entrée | Effet |
|---|---|
| Valider cette étape | Coche l'étape courante — **seulement** pour les étapes qui attendent votre confirmation |
| Passer cette étape | Coche l'étape sans la faire, et passe à la suivante |
| Masquer / afficher la checklist | Cache ou remontre l'image |
| Arrêter l'assistance | Termine la session, efface l'encadré et l'image |

Deux comportements qu'il vaut mieux connaître d'avance :

- **Les étapes déjà faites sont cochées au démarrage.** Vous pouvez lancer l'assistance en cours de
  route : ce que vous avez déjà réglé n'est pas redemandé.
- **Une étape peut être passée.** Si une étape refuse de se valider — une fenêtre de tolérance mal
  mesurée, par exemple —, `Passer cette étape` évite de rester bloqué.

Une étape **passée** apparaît cochée comme les autres sur l'image ; c'est le message texte qui vous le
signale sur le moment. L'image est le tableau de bord, les textes portent les événements.

---

## Pour le créateur de mission {#for-mission-makers}

### Activer le module {#enable}

```yaml
modules:
  ASSIST:
    enabled: true
    display: picture                # `picture` (défaut) ou `text`
    checklists: [f16c-cold-start]   # les checklists que cette mission active
```

- **Avec une liste `checklists:`** : ce sont exactement celles-là. Un `id` inconnu fait échouer la
  construction, plutôt que de laisser une entrée de menu manquer en silence.
- **Sans liste** : les checklists que vous avez déposées dans le dossier `checklists/` de votre
  mission sont activées. **Jamais tout le catalogue livré** — chaque checklist activée embarque une
  image par étape dans le `.miz`.
- **Module absent ou `enabled: false`** : rien n'est chargé, rien n'est généré, aucune image dans le
  `.miz`.

### Image ou texte {#display-mode}

`display` choisit comment la checklist s'affiche, et c'est un choix **à la construction** :

| Mode | Ce que voit le pilote | Ce que ça coûte |
|---|---|---|
| `picture` (défaut) | la checklist entière à l'écran, cases cochées au fur et à mesure | une image par étape embarquée dans le `.miz`, environ 10 Ko chacune |
| `text` | un message donnant l'instruction courante et l'avancement (`Étape 3/6 : …`) | **rien** : aucune image n'est générée ni embarquée |

Dans les deux cas la commande de cockpit est encadrée : le mode texte enlève l'image, pas
l'assistance. Une valeur inconnue fait échouer la construction — une faute de frappe ne doit pas
retomber en silence sur le mode coûteux.

Concrètement, la checklist F-16C livrée pèse 68 Ko en `picture` et 0 en `text`. À quarante étapes,
l'écart dépasse le demi-mégaoctet.

### Sans connaître les noms techniques {#instructor-path}

Une étape a besoin de l'élément du cockpit, du numéro d'animation et de la valeur qui veut dire
« en position ». Ces trois informations sont enfouies dans les fichiers Lua d'une installation DCS —
personne ne devrait avoir à les y chercher.

Décrivez plutôt le contrôle **avec vos mots**, à côté du libellé :

```yaml
steps:
  - label: Batterie
    control: MAIN PWR sur BATT      # le contrôle, puis la position voulue

  - label: Manette
    control: throttle sur IDLE
```

Puis lancez :

```bash
veaf-tools resolve-checklist checklists/ma-checklist.yaml
```

L'outil complète les champs techniques **dans votre fichier**, sous chaque `control`, et ajoute un
`resolved_from` qui retient le texte dont ils proviennent :

```yaml
  - label: Batterie
    control: MAIN PWR sur BATT
    element: PTR-ELEC-TMB-MPWR-510
    argument: 510
    equals: 0.0
    resolved_from: MAIN PWR sur BATT
```

Vos commentaires, votre indentation et vos lignes vides sont conservés : c'est votre fichier.

**Un seul fichier à maintenir.** Modifiez un `control`, relancez la commande : seules les étapes dont
le texte a changé sont retouchées — c'est à ça que sert `resolved_from`. Une étape dont le `control`
ne correspond plus à son `resolved_from` **fait échouer la construction** de la mission, plutôt que
d'embarquer une étape qui vérifierait l'ancien contrôle sans que personne ne le voie.

`--dry-run` montre ce qui serait écrit sans toucher au fichier.

#### Écrire un bon `control` {#good-control}

Nommez le contrôle **comme le cockpit le nomme**, puis la position : `throttle sur idle`, pas
« mettre les gaz ». Les mots de liaison (`sur`, `le`, `bouton`, `interrupteur`, `position`…) sont
ignorés, en français comme en anglais, et les accents et la casse n'ont pas d'importance.

#### Un refus n'est pas un échec {#refusals}

L'outil **refuse plutôt que de deviner**, parce qu'une mauvaise résolution donne une checklist qui a
l'air terminée et qui ne se validera jamais — on ne s'en aperçoit qu'une fois assis dans le cockpit.
Il refuse, en disant ce qu'il a trouvé, quand :

- aucun contrôle ne correspond ;
- plusieurs contrôles correspondent aussi bien (`MAIN PWR` et `MAIN PWR Test`) : vous seul savez ;
- la position nommée n'existe pas sur ce contrôle — il liste alors celles qui existent ;
- les valeurs des positions de ce contrôle sont inconnues. C'est le cas de la plupart des contrôles
  de l'AH-64D : écrivez `argument` et `equals` à la main, ou mesurez la position en jeu.

Si une seule étape est refusée, **rien n'est écrit** : un fichier à moitié résolu est pire qu'un
fichier non résolu.

Enfin, un contrôle **sans position lisible** — un bouton, un interrupteur à rappel comme le JFS du
F-16C — est résolu en étape validée par le pilote, et l'outil vous le dit. Ce n'est pas un défaut :
ces contrôles sont revenus au repos avant qu'on puisse les lire, quel que soit le moyen employé.

#### Vérifier une checklist dans le cockpit {#verify}

Une valeur écrite par le résolveur reste une hypothèse tant qu'on n'a pas lu le contrôle avec
l'interrupteur physiquement dans la bonne position. Cette commande le fait, avec vous aux commandes :

```bash
veaf-tools verify-checklist checklists/ma-checklist.yaml --write
```

Pour chaque étape mesurable, l'outil **encadre le contrôle dans votre cockpit** et attend que vous le
bougiez. Dès que la valeur change et se stabilise, il la lit et la compare à celle de la checklist.
Vous restez aux commandes du début à la fin : **l'outil ne manœuvre jamais rien lui-même**, il ne
fait qu'encadrer — ce qui est aussi bien pratique quand on ne sait pas où se trouve la commande.

`--write` marque `verified: true` les étapes confirmées, pour ne pas les refaire ensuite.

Trois conditions : DCS tourne **sur cette machine** (la lecture passe par `Export.lua`, qui est
local), `dcs-serve` est lancé, et la mission embarque le pont. Une valeur lue différente de celle
attendue est signalée en rouge : c'est le cas intéressant, il veut dire que la checklist a la
mauvaise valeur.

### Quel mode de validation choisir {#validation-modes}

Une étape se valide de trois façons, et le choix dépend d'abord de **où votre mission va tourner**.

| Mode | Ce qui est lu | Multijoueur |
|---|---|---|
| `argument` | la position d'une commande du cockpit | **solo et entraînement local seulement** |
| `param` | une grandeur publiée par l'appareil (altitude, vitesse, train) | partout |
| `confirm` | rien : le pilote coche lui-même | partout |

**La règle, en une phrase : si votre mission est destinée au serveur, n'utilisez pas `argument`.**
Cette lecture passe par l'environnement d'`Export.lua`, qui tourne sur la machine du pilote ; depuis
un serveur dédié elle ne fonctionnera probablement pas — ce n'est pas encore vérifié. Rien ne casse
pour autant : l'étape ne se coche jamais toute seule et le pilote utilise « Passer ».

Le résolveur produit `argument` quand il le peut, parce qu'une checklist de démarrage se vole
d'abord seul. Pour une mission de serveur, remplacez ces étapes par `confirm` — il suffit de
supprimer les lignes `argument` et `equals` et d'écrire `confirm: true`.

## Référence du format {#format-reference}

Cette partie décrit les champs techniques. Vous n'avez pas besoin de la lire pour écrire une
checklist : elle sert à relire un fichier résolu, ou à écrire à la main une étape que le résolveur a
refusée.

### Les champs d'une étape {#write-a-checklist}

Un fichier par checklist, dans `checklists/` à côté de votre `mission.yaml`. Un `id` identique à
celui d'une checklist livrée **remplace** cette dernière.

```yaml
id: f16c-demarrage            # unique ; c'est la clé de remplacement
title: Démarrage F-16C        # clé du catalogue i18n, ou texte brut
aircraft: [F-16C_50]          # types DCS concernés ; un type inconnu est refusé
menu: cold-start              # emplacement sous « Assistance »

steps:
  # Étape validée par le pilote : l'élément est encadré pour montrer où regarder
  # (`label` accepte aussi {fr: …, en: …} — voir plus bas)
  - label: MAIN PWR sur MAIN PWR
    element: PTR-ELEC-TMB-MPWR-510   # élément à encadrer dans le cockpit
    confirm: true

  # Étape validée automatiquement : on lit une grandeur publiée par l'appareil
  - label: Train sorti
    param: BASE_SENSOR_NOSE_GEAR_DOWN
    equals: 1.0                      # valeur cible…
    tolerance: 0.05                  # …à ± cette tolérance (0.05 par défaut)

  # Fenêtre large : range remplace equals + tolerance
  - label: Vitesse entre 250 et 300 kt
    param: BASE_SENSOR_IAS
    range: [128.0, 154.0]
```

Points à retenir :

- **Un `label` (et le `title`) s'écrit de trois façons** :

  | Écriture | Sens |
  |---|---|
  | `label: assist.f16c.main_pwr_batt` | clé du catalogue VEAF — ce qu'utilisent les checklists livrées |
  | `label: MAIN PWR sur BATT` | texte en clair, une seule langue |
  | `label: {fr: MAIN PWR sur BATT, en: MAIN PWR switch to BATT}` | vos traductions, écrites sur place |

  La forme avec traductions est résolue **à la construction**, dans la langue de la mission — la même
  que celle de l'image, donc les deux ne peuvent pas diverger. Si la langue demandée manque, on
  retombe sur le français, puis sur n'importe quelle traduction présente : un libellé dans la
  mauvaise langue vaut mieux que pas de libellé.
- **`element` est indépendant du mode de validation** : une jauge peut être encadrée alors que c'est
  le pilote qui dit qu'elle est bonne.
- **Trois façons de valider une étape** : `argument` (la position d'une commande), `param` (une
  grandeur publiée par l'appareil), ou rien du tout — c'est alors le pilote qui coche. Une étape en
  déclare exactement une.
- La **tolérance par défaut de 0.05** convient aux grandeurs qui valent 0 ou 1. Pour une altitude ou
  une vitesse, donnez votre propre `tolerance`, ou un `range`.
- Une erreur dans le fichier **fait échouer la construction** avec un message qui nomme le fichier
  fautif, plutôt que de produire une erreur Lua en jeu.

### Lire la position d'un interrupteur : `argument` {#switch-reading}

```yaml
  - label: MAIN PWR sur MAIN PWR
    element: PTR-ELEC-TMB-MPWR-510
    argument: 510        # l'argument d'animation de la commande
    equals: 1.0
    tolerance: 0.05
```

Le nombre en fin de nom d'élément **est** l'argument : `PTR-ELEC-TMB-MPWR-510` → `510`.

**Quelle valeur pour quelle position ?** Elle n'est pas déductible du libellé : le MAIN PWR du
F-16C affiche `MAIN PWR/BATT/OFF` et vaut +1 / 0 / −1 — dans l'ordre inverse — tandis que
`OFF/BACKUP` vaut 0 / 1. La seule source fiable, ce sont les **raccourcis clavier et joystick** de
l'appareil, qui donnent le couple position-valeur noir sur blanc :
`MAIN PWR Switch - OFF` met −1, `- BATT` met 0, `- MAIN PWR` met +1. C'est exactement ce que le
[résolveur](#instructor-path) lit à votre place ; écrire un `control` vous évite tout ce paragraphe.

**⚠️ Réserve multijoueur** : ce mode est réservé au solo et à l'entraînement local — voir
[Quel mode de validation choisir](#validation-modes).

**Deux cas où `argument` ne marchera de toute façon pas :**

- un **interrupteur à rappel** (`springloaded_*` dans `clickable_defs.lua`, comme le JFS du F-16C) est
  déjà revenu au neutre quand on le lit ;
- un **bouton** n'est pas une position : l'argument 757 du F-16C est le doigt de cut-off de la
  manette, pas la position de la manette.

Mesures et détails :
[DCS cockpit + picture API](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md).

### Trouver un `param` {#find-a-param}

Ce qu'on peut lire, c'est **l'effet** d'une commande, pas la commande. Sur un F-16C au parking,
78 grandeurs sont publiées, parmi lesquelles :

| Paramètre | Ce qu'il vaut |
|---|---|
| `BASE_SENSOR_NOSE_GEAR_DOWN` | `1` train avant sorti |
| `BASE_SENSOR_WOW_LEFT_GEAR` | `1` poids sur la roue gauche |
| `BASE_SENSOR_CANOPY_POS` | ouverture de la verrière, `0` à `1` |
| `BASE_SENSOR_FLAPS_RETRACTED` | `1` volets rentrés |
| `BASE_SENSOR_IAS` | vitesse indiquée (m/s) |
| `BASE_SENSOR_BAROALT` | altitude barométrique (m) |
| `BASE_SENSOR_HEADING` | cap (radians) |
| `BASE_SENSOR_FUEL_TOTAL` | carburant restant |

La liste dépend de l'appareil : chaque module publie ce qu'il veut. Pour voir celle du vôtre,
appelez `list_cockpit_params()` dans l'environnement mission — elle renvoie un `NOM:valeur` par ligne.

### Trouver l'élément à encadrer {#find-element}

**Le plus simple reste d'écrire un `control` et de laisser
[le résolveur](#instructor-path) le trouver** : il connaît les contrôles des appareils indexés
(F-16C, A-10C II, AH-64D, F-14B et F-14B(U)) et il vous donne le nom exact.

Pour un appareil qui n'est pas indexé, le nom se lit dans les fichiers du module, dans votre
installation DCS :

```text
<DCS>\Mods\aircraft\<Appareil>\Cockpit\Scripts\clickabledata.lua
```

Seuls les éléments **cliquables** y figurent : une jauge ou un voyant n'a pas de nom à encadrer.

Vous pouvez aussi indexer cet appareil une bonne fois, et le résolveur saura le traiter comme les
autres :

```bash
veaf-build update-dcs-data --cockpit-controls --dcs-path "C:/Program Files/Eagle Dynamics/DCS World"
```

---

## Ce que ça coûte {#cost}

L'affichage repose sur une image embarquée dans le `.miz`, et DCS ne sait afficher qu'une ressource
embarquée. La construction génère donc **une image par état d'avancement** : une checklist de douze
étapes fait treize images, soit de l'ordre de 60 à 80 Ko au total. Une mission qui n'active aucune
checklist ne paie rien.

La construction affiche le nombre d'images et leur poids total, pour que le prix soit visible au
moment où on l'engage.

---

## Limite connue {#limitations}

L'avancement affiché est **linéaire** : l'image de l'étape 5 montre les quatre premières cochées.
Une étape que le pilote a **passée** y apparaît donc cochée comme les autres. Représenter fidèlement
« passée » demanderait une image par combinaison d'états, ce qui explose. C'est le message texte qui
porte l'exception.
