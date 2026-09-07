# VEAF Mission Creation Tools — 6.20.0

**Jusqu'ici, signaler un problème demandait de savoir où le signaler, quoi joindre, et comment
écrire un ticket.** Cette version déplace le support là où vous êtes déjà — sur le Discord du VEAF —
et fait préparer le rapport par l'outillage plutôt que par vous.

Trois commandes arrivent sur le Discord : `/ask` pour interroger la documentation, `/bug` pour
signaler un défaut, `/suggest` pour proposer une idée. Côté machine, `veaf-tools doctor` et
`veaf-logs` rassemblent ce qu'un rapport doit contenir et le mettent dans le presse-papiers, prêt à
coller.

Et parce qu'une version ne se résume pas à son thème : les zones de combat replacent enfin leurs
groupes là où l'éditeur de mission les a dessinés, et Skynet fonctionne à nouveau.

---

## ⚠️ À lire avant de mettre à jour

### Un fichier `veaf-spawn-data.lua` dans votre dossier de mission est à supprimer

Si votre dossier de mission contient `src/scripts/veaf-spawn-data.lua` (ou `dcs-bridge.lua`), ce
n'est pas un script que vous avez écrit : c'est une **sortie de build**, produite à chaque
construction à partir de `src/spawn-groups.yaml` et injectée dans le `.miz`. Une extraction faite
avec une version précédente vous l'a rendue comme si c'était une source.

**Supprimez-le.** La base de spawn s'édite dans `src/spawn-groups.yaml`, jamais dans ce fichier.
Le build vous le dit maintenant explicitement, avec ce message plutôt qu'un avertissement générique.

Et attention : le déclarer sous `custom_scripts:` — ce que l'ancien message vous suggérait — ne le
sauve plus, délibérément. Cela figerait dans la mission une copie périmée de la base de spawn, en
double avec celle que le build injecte. Le fichier est simplement laissé de côté : rien n'est cassé
si vous le laissez traîner, mais il ne sert à rien.

### Un avion téléporté est de nouveau pilotable

Depuis la 6.19.0, un avion garé **froid et sombre** dans l'éditeur puis déplacé par `_move group`,
`veafSpawnObjects` ou un téléport d'escorte arrivait moteurs coupés au lieu d'arriver prêt à voler ;
un groupe masqué de la carte F10 restait masqué. Le comportement d'avant est rétabli.

---

## Le support VEAF, sur Discord

Un bot répond désormais sur le Discord du VEAF. Il tourne sur une machine du VEAF, indépendamment
des versions de l'outillage — pas besoin d'attendre une release pour qu'il évolue.

### `/ask` — poser une question à la documentation

La question ouvre un **fil public** et la réponse s'y écrit au fil de l'eau, avec les liens vers les
pages utilisées. Public volontairement : la réponse sert au suivant qui posera la même question, et
n'importe qui peut corriger le bot en passant.

Il répond **à partir de la documentation et de rien d'autre**. Une réponse fausse ou absente
signifie donc, le plus souvent, qu'une page manque — et le correctif est d'écrire la page.

**Mentionnez le bot dans le fil qu'il a ouvert** pour continuer : il garde l'échange en tête, donc
une relance peut être aussi elliptique que *« et si je veux créer une mission ? on a des modèles ? »*.
Il ne lit que les messages qui le nomment — ce n'est pas une convention polie, c'est une propriété de
la connexion : Discord ne lui livre pas le texte des messages où il n'est pas mentionné.

### `/bug` — signaler un défaut sans écrire de ticket

Un formulaire demande les cinq choses dont le modèle de rapport a besoin, et accepte jusqu'à trois
fichiers. Le reste est fait pour vous, **sans modèle d'IA** :

- le bloc `doctor` que vous collez est lu pour en tirer les versions de l'outil et de DCS ;
- une trace d'erreur (Python, journal des outils, ou erreur Lua telle que DCS l'écrit) est
  rapprochée du code, avec les lignes autour et les appelants de la fonction concernée ;
- un `dcs.log` joint est réduit à son extrait utile, et ce que le catalogue reconnaît est cité ;
- un `.miz` joint est résumé — théâtre, date, météo, *nombres* de groupes — jamais votre briefing
  ni les noms de vos groupes.

**Ce qui manque est écrit comme manquant, jamais deviné.** Une version que personne n'a collée
s'affiche *« non renseignée »* ; une trace qui nomme un fichier absent de la révision le dit, avec la
révision vérifiée et son âge.

Avant d'être publié, le rapport est **comparé à ce qui existe déjà** — les tickets ouverts, le
backlog, la feuille de route — et **il vous est montré**. Rien n'est déposé sans votre clic. Ce qui
se passe ensuite sur le ticket vous revient dans Discord.

### `/suggest` — proposer une idée, pesée contre l'existant

Le formulaire recueille d'abord le problème, ensuite le comportement souhaité. Avant de rédiger quoi
que ce soit, deux vérifications : **est-ce que ça existe déjà ?** (la documentation est interrogée) et
**est-ce que quelqu'un l'a déjà demandé ?** (les tickets, le backlog et la feuille de route sont
balayés).

Aucune des deux ne tranche seule : les deux vous sont montrées avec leurs preuves et **vous pouvez
les refuser** — un *« ça existe déjà »* erroné étoufferait une vraie idée. Là aussi, rien n'est publié
avant votre clic.

### Le quota

Les réponses de `/ask` passent par une allocation **gratuite, partagée et remise à zéro chaque
matin**. Quand elle est épuisée, le bot le dit, et vous dit jusqu'à quand — et non « réessayez dans
un instant » alors que le mur tient jusqu'au lendemain. Une relance dans un fil consomme une question
comme une autre.

---

## Préparer un rapport depuis votre machine

### `veaf-tools doctor`

Trois faits que tout rapport de bug oublie et que la machine connaît : la **version de l'outil**, la
**version de DCS**, et **où sont les journaux**. La commande affiche un tableau lisible, puis un bloc
délimité à coller tel quel dans Discord ou dans un ticket.

Tout ce qu'elle affiche est **anonymisé avant d'être montré** : votre nom de compte Windows devient
`<user>`, les adresses routables `<ip>`, jetons et mots de passe `<redacted>`. La commande fonctionne
sans DCS installé et sans journal : ce qu'elle ne peut pas lire s'affiche `unknown`, le reste est
produit quand même.

### `veaf-logs` : *Expliquer ce qui est affiché*, et *Préparer un rapport*

**Expliquer ce qui est affiché** (`Ctrl+E`) répond en deux temps, et l'ordre est tout le sujet :

1. **Le catalogue répond d'abord** — chaque motif connu est rendu avec sa formulation relue, sans
   modèle, sans coût, sans réseau. Hors ligne, cette couche marche seule et aucune erreur ne
   s'affiche.
2. **Le modèle met en contexte ensuite**, et seulement si vous cliquez *Analyser en ligne*. Là où le
   catalogue est muet, il doit répondre *« motif non catalogué »* plutôt que d'inventer une cause.

Le pire défaut d'une fonction comme celle-ci n'est pas le silence, c'est une réponse plausible et
fausse : on ne la distingue pas d'une bonne, et on y passe sa soirée. Les deux couches portent donc
leur propre titre.

Un message qui revient et que le catalogue n'explique pas vous est proposé comme **entrée
`rules.json` prête à relire**, identifiants et valeurs déjà remplacés par des jokers. Rien n'est
écrit automatiquement : le catalogue reste tenu à la main, et c'est ce qui rend ses formulations
citables.

**Préparer un rapport** assemble le bloc `doctor`, l'extrait, les correspondances du catalogue et ce
que l'analyse n'a pas su expliquer, en **un seul bloc dans le presse-papiers**, taillé pour tenir dans
un message Discord et disant ce qu'il a retiré pour y tenir. C'est un copier-coller, pas un envoi :
rien ne part de votre machine tant que vous ne collez pas.

Ce qui part, quand vous collez, est **borné et anonymisé** par le même filtre que `doctor`.

### Deux nouvelles portes dans la documentation

- Une **page support**, en français et en anglais : où aller selon votre situation, quoi fournir, et
  où se trouvent réellement les deux journaux — celui de l'outil et celui de DCS.
- *DCS se comporte mal — lire son journal*, dans le **Guide du pilote**. `veaf-logs` n'était
  documenté que côté créateur de mission ; un pilote dont DCS plante n'avait aucune raison d'ouvrir
  cette section.

---

## Corrigé en jeu

### Zones de combat

- **Un groupe revient là où l'éditeur l'a dessiné.** Trois défauts se cumulaient sur le même calcul
  de décalage. Mesuré sur une mission réelle — cinq ZU-23 en couronne autour d'Abu Musa, espacés de
  4 330 m — le groupe entier partait de **1 976 m** avec un ZU-23 perdu avant la construction de la
  zone, et de **3 340 m** dans un autre cas : de quoi poser les pièces du sud-ouest en pleine eau.
  Un navire déjà en route ou une CAP déjà en l'air emportaient en plus leur dérive depuis le début de
  la mission. Corrigé aux deux bouts : le groupe est ancré sur l'unité que l'éditeur a placée en
  premier, à sa position dessinée, vivante ou non.
- **Un élément naval cherche de l'eau, pas de la terre ferme.** Un navire ou un sous-marin mouillé
  près d'un quai était tiré sur le quai, puis refusé par le contrôle de terrain — six groupes d'une
  mission réelle n'apparaissaient jamais. Idem pour une coque posée en **objet statique**, qui était
  déplacée à terre en silence.
- **Un refus de terrain dit enfin ce qui n'allait pas** : catégorie résolue, surfaces acceptées,
  point testé, surface que DCS y a signalée — diagnosticable depuis le journal, sans le fichier de
  mission.
- **La dispersion par défaut se règle depuis `mission.yaml`.** Les 50 m par défaut posaient un
  lanceur *sur* le merlon plutôt que dedans, et sur le workflow YAML la valeur n'était pas
  modifiable. Deux clés nouvelles : `default_spawn_radius` sous `combat_zone_settings` pour toute la
  mission, et la même clé sur une entrée `combat_zones` pour une zone seule.
  `default_spawn_radius_statics` en est le pendant pour les statiques. Le `#spawnradius=` d'un groupe
  l'emporte toujours, et un `0` explicite — la valeur pour laquelle la fonction existe — est bien
  respecté.

### Skynet

**Toutes les batteries restaient endormies et la page d'état était vide**, avec
`SKYNET.enabled: true`. Aucun site n'engageait, le menu radio n'affichait ni état ni contacts, et la
même mission Skynet éteint fonctionnait parfaitement. Une seule tâche perdue expliquait les trois
symptômes : Skynet arme son cycle d'évaluation à une seconde de temps de mission, et un IADS qui
s'initialise plus tard — trois minutes, sur la mission concernée — demandait au planificateur un
instant déjà passé. Le planificateur cale désormais toute tâche due ou en retard sur le tick suivant.

### Clonage et respawn

**Un groupe cloné emporte enfin les réglages que l'éditeur lui a donnés.** La fiche interne d'un
groupe ne retenait que dix champs, et la **tâche** n'en faisait pas partie — d'où une patrouille QRA
qui décollait et « faisait sa nav tranquilos » sans mission. Sont désormais conservés `task`,
`taskSelected`, `uncontrolled`, `frequency`, `modulation`, `communication`, `radioSet` et `hidden` :
un groupe masqué dans l'éditeur ne devient plus visible sur la carte F10 dès qu'il est cloné.

### Extraction et build

**La sortie du build revenait comme source de mission** — voir *À lire avant de mettre à jour*
ci-dessus. L'extraction retire maintenant ce que la mission elle-même déclare avoir reçu d'un build
VEAF, donc un futur artefact sera couvert sans nouvelle correction.

### Assistant de documentation

- Une **en-tête suffisait à utiliser le Worker depuis n'importe où** : le quota gratuit partagé était
  ouvert à tout appelant. Corrigé.
- Le journal de l'outil enregistre enfin les **traces d'erreur**, sa rotation ne perd plus
  l'enregistrement quand un second processus tient le fichier, et `doctor` lit l'historique complet
  et non le seul journal courant.
- L'anonymisation ne **détruit plus le diagnostic** qu'elle est censée protéger, et laisse passer le
  nom du produit lui-même.

---

## Pour les développeurs

- Un emplacement pour les services longue durée : `services/support-bot/`, projet Poetry autonome,
  déployé indépendamment de la release des outils. Son image est construite par la CI et publiée sur
  GHCR — la machine hôte ne clone plus ce dépôt pour le faire tourner.
- Deux contrats versionnés, avec analyseur, test aller-retour et documentation : le bloc de
  diagnostic (`veaf-tools-doctor/1`) et le bloc de rapport (`veaf-logs-report/1`).
- Le filtre d'anonymisation est mutualisé dans `veaf_libs.redaction`, placé sous **tous** les chemins
  de publication plutôt que demandé à chacun d'eux.

---

*Merci à **Tripack**, dont les retours de terrain ont produit une bonne part des correctifs de cette
version — la sortie de build revenue en source, Skynet endormi, et les zones de combat décalées.*
