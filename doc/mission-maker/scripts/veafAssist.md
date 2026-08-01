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
    checklists: [f16c-cold-start]   # les checklists que cette mission active
```

- **Avec une liste `checklists:`** : ce sont exactement celles-là. Un `id` inconnu fait échouer la
  construction, plutôt que de laisser une entrée de menu manquer en silence.
- **Sans liste** : les checklists que vous avez déposées dans le dossier `checklists/` de votre
  mission sont activées. **Jamais tout le catalogue livré** — chaque checklist activée embarque une
  image par étape dans le `.miz`.
- **Module absent ou `enabled: false`** : rien n'est chargé, rien n'est généré, aucune image dans le
  `.miz`.

### Écrire une checklist {#write-a-checklist}

Un fichier par checklist, dans `checklists/` à côté de votre `mission.yaml`. Un `id` identique à
celui d'une checklist livrée **remplace** cette dernière.

```yaml
id: f16c-demarrage            # unique ; c'est la clé de remplacement
title: Démarrage F-16C        # clé du catalogue i18n, ou texte brut
aircraft: [F-16C_50]          # types DCS concernés ; un type inconnu est refusé
menu: cold-start              # emplacement sous « Assistance »

steps:
  # Étape validée par le pilote : l'élément est encadré pour montrer où regarder
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

- **Un `label` peut être une phrase**, pas forcément une clé de catalogue : une clé inconnue est
  renvoyée telle quelle, donc vous pouvez écrire directement votre texte.
- **`element` est indépendant du mode de validation** : une jauge peut être encadrée alors que c'est
  le pilote qui dit qu'elle est bonne.
- **`param` implique une validation automatique**, sans `param` c'est le pilote qui valide.
- La **tolérance par défaut de 0.05** convient aux grandeurs qui valent 0 ou 1. Pour une altitude ou
  une vitesse, donnez votre propre `tolerance`, ou un `range`.
- Une erreur dans le fichier **fait échouer la construction** avec un message qui nomme le fichier
  fautif, plutôt que de produire une erreur Lua en jeu.

### On ne peut pas lire la position d'un interrupteur {#no-switch-reading}

C'est la limite structurante de ce module, et elle a été **mesurée en jeu** : un script de mission
ne voit pas la position des commandes du cockpit. L'interrupteur MAIN PWR d'un F-16C a été déplacé
sur ses trois positions sans qu'aucun des trois mécanismes disponibles ne bouge. Le cockpit est un
modèle séparé et son état ne remonte pas jusqu'à la mission ; les checklists d'entraînement d'ED y
arrivent parce que leur code tourne *dans* le cockpit du module, ce qui nous est fermé.

Conséquence pratique : **une étape « mettre tel interrupteur sur telle position » se valide en
`confirm`**. C'est le cas des six étapes de la checklist F-16C livrée.

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

Il se lit dans les fichiers du module d'appareil, dans votre installation DCS :

```text
<DCS>\Mods\aircraft\<Appareil>\Cockpit\Scripts\clickabledata.lua
```

Seuls les éléments **cliquables** y figurent : une jauge ou un voyant n'a pas de nom à encadrer.

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
