# VEAF Mission Creation Tools — 6.26.0

**Cette version vient du premier vol dans une mission construite par l'assistant.** *Open Training
Germany Cold War*, rebâtie avec les outils dans la version précédente, a été jouée sur le serveur le
29 septembre. Ce qui a cassé en vol se retrouve ici : des objectifs qui n'apparaissaient jamais, des
commandes radio sécurisées refusées à tout le monde, un C-130 posé à Ramstein sans rien à charger, des
réglages acceptés puis ignorés.

> ### ⚠️ Ce qui change dans vos missions et sur vos serveurs
>
> **1. Serveurs : redéployez `VEAF-Server-hook.lua`.** Le hook envoie maintenant le niveau du pilote à
> chaque changement de slot. Sans le nouveau hook, un pilote resté connecté pendant un rechargement de
> mission garde un niveau vide et se voit refuser les commandes `+`.
>
> **2. Les aérodromes deviennent des points logistiques CTLD.** C'est actif par défaut sur toute
> mission qui utilise CTLD. Pour garder l'ancien comportement :
> `modules.CTLD.manage_airbase_logistics: false`.
>
> **3. Une QRA marquée `start: false` par la conversion v5 n'est plus armée au démarrage.** Elle
> l'était jusqu'ici malgré ce réglage. Si vous comptiez sur elle au démarrage, passez-la à
> `active_at_start: true`.
>
> **4. `logLevel` sous un module prend enfin effet.** Il n'avait jamais été appliqué. Un module réglé
> sur `trace` ou `debug` dans votre `mission.yaml` va maintenant remplir le `dcs.log`.
>
> **5. Un `-farp` sans place pour son escorte est refusé** au lieu de poser l'escorte n'importe où. En
> jeu, ce refus n'est arrivé dans aucun des quatre essais, forêt dense comprise. Une FARP placée dans
> l'éditeur de mission n'est jamais refusée.
>
> **6. `/secu login` et `/secu logout` ne déverrouillent plus rien** (ils ne le faisaient déjà plus,
> tout en répondant le contraire). Ils renvoient vers `/secu elevate`. Le réglage `authDuration` est
> retiré ; une mission qui le pose encore n'est pas affectée.

---

## 🔐 Les commandes radio sécurisées fonctionnent à nouveau

Depuis 6.14.0, une commande sécurisée destinée à tous (activer ou désactiver une zone de combat
hors entraînement, le brouillard, sauter une mission CAS ou de transport, nettoyer les convois,
l'élingage CTLD…) répondait *« Your radio has to be authenticated for '+' commands »* à chaque clic,
quel que soit le pilote. Elle est désormais proposée dans le menu de chaque groupe de pilotes, là où
le niveau du groupe est vérifié. Un maître du jeu, qui n'a pas de groupe, ne la voit plus quand la
sécurité est active ; sans sécurité, tout le monde la voit comme avant.

Et un pilote inscrit dans `veaf-pilots.txt` retrouve son niveau **sans taper aucune commande**, même
si la mission a été rechargée pendant qu'il restait connecté (voir l'avertissement n° 1). Un refus
indique maintenant au groupe le niveau requis et le niveau dont il dispose, à ce groupe seulement. Une
commande de chat mal tapée (`/sec`, `/veaflogin`) répond par la liste des commandes existantes au lieu
d'écrire une erreur dans le journal.

---

## 🚁 CTLD : on charge et on décharge sur les aérodromes

Un C-130 posé à Ramstein lisait *« No logistics in range »* : aucun aérodrome de la carte n'était un
point logistique pour CTLD. VEAF enregistre maintenant chaque aérodrome au démarrage, par une zone de
250 m autour de son parking.

- Un aérodrome tenu au début de la mission reste ouvert tant que son camp le tient.
- Un aérodrome neutre ou capturé ne s'ouvre qu'après **deux minutes d'occupation au sol sans
  opposition**, et se referme dès que les dernières troupes partent. Un avion de transport qui se pose
  sur un terrain capturé ne suffit donc pas à l'ouvrir.
- Chaque aérodrome actif est dessiné en cercle vert sur la carte F10 du camp qui le tient, et chaque
  changement est annoncé au camp qui le gagne ou le perd.

Réglages : `airbase_logistics_radius`, `airbase_occupation_radius`, `airbase_logistics_tick`.
CTLD lui-même n'est pas modifié.

---

## 🎯 Les objectifs d'une mission construite par l'assistant existent vraiment

Premier test en jeu d'une mission bâtie par l'assistant IA, et ce qu'il a trouvé :

- **Quatre objectifs n'apparaissaient jamais.** DCS refusait sans rien dire un poste de commandement
  et trois dépôts de munitions, faute de la forme (`shape_name`) que l'éditeur écrit. Les objets
  statiques la portent maintenant, et `validate` signale ceux construits avant.
- **Une zone faite uniquement d'objets statiques s'affichait vide.** Le panneau d'information d'une
  zone ne comptait que les groupes : une zone à cinq cibles fixes n'y listait aucun ennemi alors
  qu'elle attendait leur destruction. Les statiques y apparaissent désormais comme des structures.
- **Une zone de combat était initialisée deux fois** (Torgau portait 8 éléments au lieu de 4).
- **Les avions partaient sans leurres**, sans indicatif, et avec des numéros de queue qui
  recommençaient à 10 dans chaque groupe. Ils reçoivent maintenant la dotation de leurres que l'éditeur
  donne à leur type, une famille d'indicatifs selon leur tâche (Enfield…, Texaco… pour un
  ravitailleur, Overlord… pour un AWACS) et des numéros uniques.
- **Un porte-avions était ouvert à tous les appareils du camp**, B-52H compris. Seuls ceux qui peuvent
  décoller **et** apponter sur son pont y sont désormais proposés ; une liste `aircrafts:` explicite
  reste respectée.
- Au démarrage, `ctld-config.yaml` ne produit plus 35 avertissements *« not found »* hérités de
  l'exemple de CTLD, et `validate` signale un nom qui n'existe pas dans la mission.
- Les listes de villes utilisées pour nommer les points couvrent maintenant GermanyCW, Sinaï,
  Normandie, Afghanistan et Marianas WWII ; la Syrie passe de 213 à 1 151 villes.

L'assistant sait aussi placer **un groupe aéronaval complet** — porte-avions et escorte en route,
fréquences, TACAN, ICLS, Link 4 et ACLS, ravitailleur S-3B et hélicoptère de sauvetage — ainsi que des
**slots sur le pont**, à froid ou à chaud, et des **balises radio** qui diffusent un son.

---

## 🌲 Le placement hors des arbres, repris depuis le début

**Les chiffres annoncés en 6.25.0 étaient faux.** Ils avaient été comptés après l'apparition des
véhicules, alors que la sonde de DCS qui dit « y a-t-il de la place ici » compte aussi les
**véhicules** comme des obstacles. Une batterie serrée échouait donc à son propre test, où qu'on la
pose.

Mesuré là où il faut, c'est-à-dire avant que les véhicules existent, le bilan était beaucoup plus
modeste. La méthode a donc été changée : chaque proposition de DCS est vérifiée véhicule par véhicule,
et comme DCS ne propose rien du tout aux endroits qui en ont le plus besoin, les outils cherchent
maintenant eux-mêmes, par cercles de plus en plus larges autour du groupe, le premier décalage où tous
les véhicules sont sur un sol praticable et dégagé. La formation reste intacte, au centimètre près.

Sur une version intermédiaire, les véhicules encore sous les arbres étaient passés de 17 à 4. **La
version livrée n'a pas encore été mesurée en jeu.** Le déplacement est maintenant borné à 300 m au lieu
de 1 000.

**L'assistant place aussi ses groupes sur un terrain dégagé**, jusqu'à 1 km de la position demandée, et
le dit. Il s'appuie sur un catalogue du terrain dégagé, relevé une fois dans DCS : Caucase (ses 21
aérodromes) et GermanyCW (les 25 zones de combat de GermanyCW-v6) sont livrés. `keep_position: true`
garde la position que vous avez donnée. Deux commandes guidées vont avec :

```powershell
.\veaf-tools.exe dcs clear-ground-sweep Caucasus
.\veaf-tools.exe dcs clear-ground-check .\build\ma-mission.miz
```

La première relève un théâtre ou les zones d'une mission ; elle prépare la mission de relevé, lance le
pont avec DCS, vous dit quoi faire dans le jeu, et reprend là où un relevé interrompu s'était arrêté.
La seconde vérifie une mission construite, sans rien faire apparaître.

Les escortes de FARP posées en terrain dégagé restent désormais à l'endroit prévu (voir
l'avertissement n° 5).

---

## ⚙️ Des réglages QRA et AIRWAVES qui étaient acceptés puis ignorés

- Une commande VEAF (`[0,0]-spawn …`, `-sa6`) dans la liste de déploiement d'une QRA n'est plus
  refusée par `validate` ; le jeu l'a toujours exécutée.
- `respawn_default_offset` sous une QRA arrive enfin dans le Lua généré.
- Une vague AIRWAVES dont `groups` est une liste YAML donne bien une liste de groupes, et non plus un
  seul groupe nommé `"['a', 'b']"`.
- `validate` signale une clé de QRA que le build ne lit pas, et un niveau de journal inconnu.

---

## 🛩️ Planchettes et radios

- **Les noms accentués arrivent intacts dans le cockpit.** « Nörvenich » devenait « NÃ¶rvenich » dans
  chaque radio et sur chaque planchette (127 canaux sur l'Open Training GermanyCW) ; les fréquences,
  elles, étaient justes.
- **La planchette numérote les canaux comme le cockpit** sur le Mi-24P (à partir de 00) et l'OH-58D
  (emplacements « M » et « C » nommés, puis canaux à partir de 01).
- Sur l'OH-58D, une liste de moins de 20 canaux ne décale plus tous les numéros d'un cran. Trouvé dans
  le code, pas encore vérifié dans le cockpit.
- Sur une machine sans les polices Windows, les planchettes gardent leur mise en page.

---

## 🧭 Et encore

- **Suivre une zone de combat en direct dans `dcs.log`** : `module_settings: { veaf.Diagnostics:
  true }` fait écrire à chaque zone son activation, chaque élément apparu ou manqué, le contenu de son
  panneau et sa désactivation. Désactivé par défaut, à réserver à une session que quelqu'un surveille.
- **Un `dcs.log` par défaut est plus calme** : 56 lignes d'information sur 217 passent en débogage.
- **Les véhicules terrestres apparus par script démarrent chauds**, avec une signature infrarouge dès
  la première seconde. Un véhicule coché *COLD AT START* dans l'éditeur le reste à sa réapparition.
- **L'escorte d'un ravitailleur téléporté** reprend sa mission sur le bon point de route, et un
  ravitailleur, son escorte ou un AFAC déplacés réapparaissent sur la route dessinée dans l'éditeur, et
  non plus sur la route modifiée.
- **Le suivi des contacts de Skynet** ne perd plus un contact sur deux quand plusieurs sortent de la
  couverture en même temps.
- **Le programme de mise à jour** se remplace correctement dans un dossier de mission accentué
  (« Mission élève »).
- **Le menu radio VEAF** affiche toutes ses entrées de premier niveau en majuscules.
- **Les invites de l'assistant** demandent des cartes de briefing zoomées, visibles côté bleu
  seulement : DCS montrait les images rouges puis bleues aux joueurs de camp inconnu, soit chaque carte
  deux fois.

---

## 📜 `veaf-logs`

- Il lit maintenant **les autres journaux d'un serveur** : DCSServerBot, Real Weather et LotAtc, ligne
  par ligne, avec leur heure et leur niveau. Le journal de DCSServerBot, 4 104 lignes, s'affichait
  jusqu'ici en une seule entrée. Le bruit de fond de ces outils est masquable.
- Le **panneau des filtres se masque** (`Ctrl+B`), et l'exécutable a enfin une icône.
- Il pèse **48 Mo au lieu de 69**.
- Il refuse les signatures SSH `ssh-rsa` en SHA-1 (CVE-2026-44405) ; les clés RSA restent acceptées
  via `rsa-sha2-256` / `rsa-sha2-512`.

---

## 🙏 Contributions

Merci à tous les copains de la VEAF qui ont passé des heures en vol à tester — copains d'abord,
cobayes ensuite, et rarement l'inverse. Presque tout ce qui est corrigé ici, c'est vous qui l'avez
trouvé, en vol, sur la session Open Training GermanyCW du 29 septembre 2026.
