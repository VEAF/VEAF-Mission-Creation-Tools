# VEAF Mission Creation Tools — 6.19.0

**Paluche a suivi le tutoriel du début à la fin, et il a trouvé trois instructions impossibles à
exécuter.** Pas des imprécisions : des étapes qui demandent une chose que l'outil ne permet pas.
Cette version les corrige, et corrige au passage un défaut qu'il a trouvé en vol — la fumée qui ne
sortait pas.

C'est le genre de retour qu'aucune suite de tests ne remplace : le tutoriel était vert de tous les
contrôles automatiques, et infaisable pour quelqu'un qui le lit pour la première fois.

---

## ⚠️ À lire avant de mettre à jour

### La fumée et les fusées de signalisation ne sortaient plus

Depuis la **6.18.0**, une demande de fumée pouvait n'avoir aucun effet : le message de confirmation
s'affichait, et rien n'apparaissait.

Ça touchait la fumée d'une **zone de combat**, mais aussi les commandes de marqueur
**`_spawn smoke`** et **`_spawn flare`** — toutes trois demandent un seul obus par défaut, et c'est
exactement le cas qui était perdu. Une demande de plusieurs obus (`#shells=3`) sortait, elle : seul
le premier était affecté.

La cause est dans la 6.18.0, où VEAF a cessé d'utiliser MiST pour planifier ses tâches. MiST
exécutait au tick suivant tout ce qui était en retard ; le remplacement passait l'heure demandée
telle quelle au planificateur de DCS, et ces trois effets demandent « maintenant ». Le planificateur
VEAF cale désormais toute tâche due — ou en retard — sur le tick suivant.

**Si vous observez encore une fumée qui se confirme sans apparaître, dites-le** : la cause exacte
côté DCS n'a pas pu être établie depuis un poste de développement, et le correctif a été écrit pour
être juste dans les deux cas.

### `prepare --template` ne remplace plus votre `mission.yaml` sans le demander

`prepare` demande fichier par fichier s'il faut remplacer ou garder — mais avec `--template`, il
réécrivait `mission.yaml` de toute façon. Répondre « tout garder » sauvait donc tous vos fichiers
**sauf** celui qui porte votre configuration de modules, votre bloc de sécurité et vos réglages de
build.

C'est comme ça que Paluche a perdu ses modifications, alors qu'il essayait de restaurer un fichier
sans rapport.

Désormais la réponse est respectée, et si vous gardez votre fichier, l'outil vous dit que le
template **n'a pas été appliqué** — parce que dans ce cas `--template` n'a rien fait du tout.

**Si vous scriptez `prepare --template` en comptant sur l'écrasement, ajoutez `--force`.**

---

## Le tutoriel, réparé

[Le tutoriel](https://veaf.github.io/documentation/mission-maker/TUTORIAL/) mène du dossier vide à
une mission qui tourne. Trois de ses étapes ne pouvaient pas être suivies :

- **Étape 5** demandait de *créer* une mission et de l'enregistrer sous le nom du fichier construit
  à l'étape 4 — deux fichiers pour un seul nom, alors que la page dit vingt lignes plus bas que le
  fichier à rouvrir est celui de la racine. On rouvre maintenant le `.miz` que le build vient de
  produire, ce qui est d'ailleurs la boucle que le tutoriel enseigne partout ailleurs.

- **Étape 7** faisait restaurer un fichier avec `git checkout`, dans un dossier que le tutoriel
  n'avait jamais transformé en dépôt Git. La commande ne pouvait pas fonctionner. On restaure
  maintenant par copie, et la gestion de versions est expliquée pour ce qu'elle est — un outil qui
  s'apprend pour lui-même, avec un lien vers un cours gratuit — au lieu d'être une commande à taper
  au milieu d'un premier parcours.

- **Étape 8** faisait décommenter un bloc `COMBATZONE` que le modèle choisi à l'étape 1 n'écrit
  pas. Le tutoriel utilise désormais le modèle `standard`, où le bloc existe, et la règle du
  décommentage est écrite noir sur blanc : on retire le `#` **et les trois espaces qui le suivent**,
  jamais l'indentation. En YAML, l'indentation *est* la structure, et c'est l'erreur qui coûte une
  heure.

Deux autres étapes ont été reprises pour la même raison. **L'étape 9** demandait d'attribuer un
aérodrome à la coalition bleue — ce qui est déjà fait dès qu'on y a posé un slot bleu à l'étape 5 :
c'est devenu une vérification. Et **l'étape 4** prévient d'un piège de nommage : le nom que vous
donnez au build n'est conservé que s'il se termine par `.miz`. Sans l'extension, le fichier reçoit
la date du jour, et on ne reconnaît plus « le fichier de la racine » que la page ne cesse de citer.

---

## Le build dit ce qu'il a lu

Ajouter une zone de combat à `mission.yaml` et lancer le build ne donnait aucun signe que la zone
avait été prise en compte. Le build annonce maintenant les modules qu'il a lus, avec le nombre
d'entrées pour ceux qui portent une liste :

> Modules VEAF actifs (23) : AIRBASES, CACHE, CARRIER, CASMISSION, **COMBATZONE (1)**, COMMANDS, …

Le nombre est le plus utile : une liste `combat_zones:` qui n'a rien donné ressemblait exactement à
un build en bonne santé. `COMBATZONE (0)` vous dit qu'il y a un problème d'écriture ; l'absence de
`COMBATZONE` vous dit que le bloc n'est pas au bon endroit dans le fichier.

C'est aussi le contrôle qui manquait à l'étape 8 du tutoriel : on sait maintenant que la zone est
passée **avant** de lancer DCS.

---

## Merci

À **Paluche**, pour avoir suivi le tutoriel jusqu'au bout et écrit ce qu'il a rencontré, étape par
étape. Ses cinq remarques sont toutes fondées, et trois d'entre elles décrivaient des instructions
que personne ne pouvait exécuter. Un tutoriel ne se teste pas autrement que comme il l'a fait.

Et le rappel de la 6.18.0 vaut encore : **la plupart des défauts corrigés ici ont été trouvés en
usage, pas par les tests**. Les tests de la fumée, eux, ne vérifiaient rien du tout — ils
s'assuraient que l'appel ne plantait pas, sans jamais regarder si l'effet arrivait dans le jeu. Ils
le vérifient maintenant.
