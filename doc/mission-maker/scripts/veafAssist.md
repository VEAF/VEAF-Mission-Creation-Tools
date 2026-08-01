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
  # Étape validée automatiquement : on lit un argument d'animation du cockpit
  - label: MAIN PWR sur MAIN PWR
    element: PTR-ELEC-TMB-MPWR-510   # élément à encadrer dans le cockpit
    argument: 510                    # argument d'animation à lire
    equals: 1.0                      # valeur cible…
    tolerance: 0.05                  # …à ± cette tolérance (0.05 par défaut)

  # Étape validée par le pilote : l'élément est encadré quand même, pour montrer où regarder
  - label: Voyant JFS RUN allumé — vérifier
    element: PTR-ENGSTART-TMB-JETFUEL-447
    confirm: true

  # Fenêtre large : range remplace equals + tolerance
  - label: Manette entre IDLE et MIL
    argument: 757
    range: [0.2, 0.9]
```

Points à retenir :

- **Un `label` peut être une phrase**, pas forcément une clé de catalogue : une clé inconnue est
  renvoyée telle quelle, donc vous pouvez écrire directement votre texte.
- **`element` est indépendant du mode de validation** : une jauge peut être encadrée alors que c'est
  le pilote qui dit qu'elle est bonne.
- **`argument` implique une validation automatique**, sans `argument` c'est le pilote qui valide.
- **Un interrupteur à rappel** (qui revient tout seul en position neutre) ne peut pas être détecté
  par son argument : utilisez `confirm: true`.
- Une erreur dans le fichier **fait échouer la construction** avec un message qui nomme le fichier
  fautif, plutôt que de produire une erreur Lua en jeu.

### Trouver l'élément et l'argument {#find-element-and-argument}

Les deux se lisent dans les fichiers du module d'appareil, dans votre installation DCS :

```text
<DCS>\Mods\aircraft\<Appareil>\Cockpit\Scripts\clickabledata.lua
```

Le nombre en fin de nom d'élément **est** l'argument d'animation :
`PTR-ELEC-TMB-MPWR-510` → argument `510`.

La **fenêtre**, en revanche, se mesure : un interrupteur à trois positions peut aller de `0` à `1`
ou de `-1` à `+1`. Relevez la valeur pour **chaque** position, pas seulement celle qui vous
intéresse, et choisissez une tolérance assez étroite pour rejeter la position voisine.

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
