# Assistant IA d'édition de mission — catalogue des actions

> **Public visé** : les Mission Makers qui pilotent l'édition de leur mission avec une IA
> (Claude) branchée sur le serveur MCP `veaf-mission-mcp`.
>
> 🇬🇧 [`AI_ASSISTANT_CATALOG.en.md`](AI_ASSISTANT_CATALOG.en.md)
>
> 📓 Doc technique (développeurs/intégrateurs) : [`developer/mission-editing-mcp.md`](../developer/mission-editing-mcp.md).

Cette page liste **tout ce que tu peux demander à l'IA** aujourd'hui, en langage naturel. Tu
n'as pas besoin de connaître les noms techniques : tu formules ta demande, l'IA choisit l'action.

> 🌱 **Doc vivante** — ce catalogue s'étoffe à chaque nouvelle capacité ajoutée au MCP. La
> colonne « fréquence » est une **estimation** d'usage, amenée à être ajustée avec le retour
> terrain.

## Deux niveaux d'édition (à garder en tête)

L'IA peut agir à deux endroits, et ça change ce qui « survit » :

- **La recette (le `mission.yaml` source)** — le fichier de configuration à partir duquel l'outil
  VEAF *fabrique* ta mission. Modifier la recette est **durable** : la prochaine reconstruction
  repart de la config à jour. C'est le niveau à privilégier pour tout ce qui est configuration.
- **La mission déjà construite (le `.miz`)** — retouches directes sur le fichier de mission
  final, **sans reconstruction**. Rapide et pratique pour un ajustement ponctuel, mais une
  reconstruction depuis la recette **écrasera** ces retouches.

> 🛟 **Filet de sécurité** : avant *chaque* modification, l'IA fait une **sauvegarde horodatée**
> du fichier concerné. Rien n'est écrasé sans copie. Dans un dossier de mission, les copies vont dans
> `.veaf-backups/` à la racine du dossier — ni dans `src/`, que le build empaquette, ni dans vos
> commits (le répertoire s'ignore lui-même) — et seules les 20 dernières de chaque fichier sont gardées.

## Légende des fréquences

| Icône | Fréquence estimée |
|-------|-------------------|
| 🔥 | Très fréquent (à chaque session d'édition) |
| ⭐ | Fréquent |
| ◽ | Occasionnel |
| 🔧 | Avancé / rare |

## Index complet

| # | Action (en langage courant) | Thème | Niveau | Fréq. |
|---|------------------------------|-------|--------|-------|
| 1 | [Lister les groupes et zones déjà présents](#list-groups-and-zones) | État de la mission | Mission construite | 🔥 |
| 2 | [Inspecter les unités, leurs emports et leurs routes](#inspect-units) | État de la mission | Mission construite | 🔥 |
| 3 | [Lister les modules VEAF et leur réglage](#list-veaf-modules) | État de la mission | Recette | 🔥 |
| 4 | [Ajouter un groupe terrestre / véhicules](#add-a-group) | Ordre de bataille | Mission construite | ⭐ |
| 5 | [Modifier un appareil ou un véhicule existant](#change-a-unit) | Ordre de bataille | Mission construite | ⭐ |
| 6 | [Déplacer, renommer ou reconfigurer un groupe](#change-a-group) | Ordre de bataille | Mission construite | ⭐ |
| 7 | [Modifier la route d'un vol et ce qu'il y fait](#change-a-route) | Ordre de bataille | Mission construite | ⭐ |
| 8 | [Activer / désactiver / configurer un module (recette)](#configure-a-module-recipe) | Modules & réglages | Recette | ⭐ |
| 9 | [Activer / désactiver un module (mission construite)](#enable-a-module-built) | Modules & réglages | Mission construite | ⭐ |
| 10 | [Changer le niveau de logs](#log-level) | Modules & réglages | Recette + construite | ◽ |
| 11 | [Activer / désactiver la sécurité par mot de passe](#password-security) | Modules & réglages | Recette + construite | ◽ |
| 12 | [Régler un paramètre VEAF précis](#veaf-parameter) | Modules & réglages | Recette + construite | ◽ |
| 13 | [Ajouter une zone de déclenchement circulaire](#add-a-zone) | Zones & déclencheurs | Mission construite | ◽ |
| 14 | [Modifier une zone (déplacer, redimensionner, polygone)](#change-a-zone) | Zones & déclencheurs | Mission construite | ◽ |
| 15 | [Ajouter un script au démarrage de la mission](#startup-script) | Zones & déclencheurs | Mission construite | ◽ |
| 16 | [Dessiner sur la carte F10](#draw-on-the-f10-map) | Zones & déclencheurs | Mission construite | ◽ |
| 17 | [Rechercher-remplacer du texte dans les scripts](#search-replace) | Retouches avancées | Mission construite | 🔧 |
| 18 | [Lister les types d'unités DCS](#list-dcs-units) | Connaissance métier | — | ⭐ |
| 19 | [Lister les alias / raccourcis VEAF](#list-veaf-aliases) | Connaissance métier | — | ⭐ |
| 20 | [Expliquer les conventions de nommage](#naming-conventions) | Connaissance métier | — | ◽ |
| 21 | [Renseigner sur un module VEAF](#describe-module) | Connaissance métier | — | ◽ |
| 22 | [Vérifier un nom de groupe](#check-group-name) | Connaissance métier | — | ◽ |
| 23 | [Créer une combat zone complète (une passe)](#create-combat-zone) | 🏗️ Composites | Recette (dossier) | 🔥 |
| 24 | [Créer une QRA complète (une passe)](#create-qra) | 🏗️ Composites | Recette (dossier) | 🔥 |
| 25 | [Créer une mission CAP à la demande (une passe)](#create-cap) | 🏗️ Composites | Recette (dossier) | ⭐ |
| 26 | [Créer un dossier de mission depuis zéro](#create-mission-folder) | 🏗️ Démarrage | Dossier | ⭐ |
| 27 | [Lire la carte (repérage)](#read-the-map) | 🗺️ Carte & coordonnées | — | ⭐ |
| 28 | [Convertir des coordonnées (x/y ↔ lat/lon)](#convert-coordinates) | 🗺️ Carte & coordonnées | — | ◽ |
| 29 | [Placer par nom de lieu réel (géocodage)](#geocode) | 🗺️ Carte & coordonnées | — | ⭐ |
| 30 | [Valider une mission avant build](#validate-mission) | 🏁 Valider & construire | Dossier | ⭐ |
| 31 | [Construire le .miz jouable](#build-mission) | 🏁 Valider & construire | Dossier | 🔥 |
| 32 | [Colorer une base et activer ses slots dynamiques](#colour-base) | 🛫 Bases & aérodromes | Recette (dossier) | 🔥 |
| 33 | [Dater la mission et régler son heure de départ](#mission-date) | 🕰️ Réglages de la mission | Recette + construite | ⭐ |
| 34 | [Placer le bullseye d'une coalition](#set-bullseye) | 🕰️ Réglages de la mission | Recette + construite | ⭐ |
| 35 | [Écrire le briefing](#set-briefing) | 🕰️ Réglages de la mission | Recette + construite | ⭐ |
| 36 | [Connaître les limites connues](#known-limitations) | Connaissance métier | — | ⭐ |
| 37 | [Lister les aérodromes d'un théâtre](#list-airfields) | 🛫 Bases & aérodromes | — | ⭐ |
| 38 | [Poser un FARP complet](#add-farp) | 🛫 Bases & aérodromes | Recette + construite | ⭐ |
| 39 | [Régler la météo de la mission](#set-weather) | 🕰️ Réglages de la mission | Recette + construite | ⭐ |
| 40 | [Poser un groupe aéronaval complet](#add-carrier) | 🛫 Bases & aérodromes | Recette + construite | ◽ |
| 41 | [Embarquer un son dans la mission](#add-sound) | Zones & déclencheurs | Recette + construite | ◽ |
| 42 | [Donner aux bases leurs vraies fréquences radio](#airfield-channels) | 🛫 Bases & aérodromes | Recette (dossier) | ⭐ |
| 43 | [Connaître l'altitude du sol et le masquage par le relief](#terrain-elevation) | 🗺️ Carte & coordonnées | — | ⭐ |
| 44 | [Lister les emports par défaut d'un avion](#list-payloads) | Connaissance métier | — | ⭐ |
| 45 | [Compléter les statiques posés sans forme](#repair-static-shapes) | 🏁 Valider & construire | Recette + construite | ◽ |
| 46 | [Créer une opération (zones enchaînées)](#create-operation) | 🏗️ Composites | Recette (dossier) | ◽ |
| 47 | [Ajouter une image au briefing](#briefing-picture) | 🕰️ Réglages de la mission | Recette + construite | ◽ |
| 48 | [Lire où en est une campagne](#campaign-status) | 🎖️ Campagne | Campagne (dossier) | ⭐ |
| 49 | [Appliquer une mission de campagne jouée](#campaign-apply) | 🎖️ Campagne | Campagne (dossier) | ⭐ |
| 50 | [Préparer la mission suivante d'une campagne](#campaign-next) | 🎖️ Campagne | Campagne (dossier) | ⭐ |

---

## 🧠 Connaissance métier (l'IA sait DCS + VEAF)

*L'IA s'appuie sur ces sources pour choisir les bons types d'unités, nommer correctement les
groupes et configurer les modules — sans que tu aies à connaître les détails techniques. Elles
sont lues depuis les données canoniques VEAF (générées / vendorisées), donc toujours à jour. Tu
peux aussi les interroger directement.*

### Lister les types d'unités DCS {#list-dcs-units}

*Connaissance · ⭐* — Types d'unités DCS (filtrables par catégorie ou par nom), depuis la base
générée par `update-dcs-data`.

> 💬 *« Quels chasseurs russes sont dispo ? »* · *« Montre-moi les SAM DCS. »*

Chaque arme et chaque radar porte sa portée telle que DCS la donne (les cercles de l'éditeur de
mission) : de quoi vérifier qu'une batterie n'atteint pas une base adverse.

### Lister les emports par défaut d'un avion {#list-payloads}

*Connaissance · ⭐* — Les emports que l'éditeur de mission propose pour un avion piloté par l'IA,
par leur nom (« R-40T*2,R-33*4 » pour un MiG-31). L'IA peut ensuite armer un vol, une QRA ou une CAP
par ce nom, sans recopier les armes une à une.

> 💬 *« Arme les MiG-31 de la QRA avec leur emport R-33. »*

### Lister les alias / raccourcis VEAF {#list-veaf-aliases}

*Connaissance · ⭐* — Le vocabulaire d'alias VEAF (`shilka`, `sa8`, …) pour le spawn d'unités et
de groupes composites (SAM sites, convois), et les raccourcis `-samLR`, `-armor`… avec la plage de
chaque paramètre qu'ils tirent au hasard (`defense`, `armor`, `size`).

> 💬 *« C'est quoi l'alias pour une Shilka ? »* · *« Liste les groupes SAM tout faits. »*

### Expliquer les conventions de nommage {#naming-conventions}

*Connaissance · ◽* — Les motifs de nommage réservés (combat zone, `veafSpawn-`, `#command`,
interpréteur…) que l'IA doit respecter pour ne pas casser une mission.

> 💬 *« Pourquoi mon groupe disparaît au démarrage ? »* (l'IA vérifie les conventions)

### Renseigner sur un module VEAF {#describe-module}

*Connaissance · ◽* — Vérifie qu'un module existe, pointe vers sa page de doc, et dit s'il est
activé dans une mission donnée.

> 💬 *« Le module QRA, ça se configure comment ? »*

### Vérifier un nom de groupe {#check-group-name}

*Connaissance · ◽* — Contrôle qu'un nom de groupe ne tombe pas dans un motif réservé
(préfixe `veafSpawn-`/`OnDemand-`, marqueurs `#command`/interpréteur, syntaxe QRA…) et, sur une
mission donnée, prévient du **piège de capture combat-zone**. L'IA s'en sert avant d'ajouter un
groupe et te relaie tout avertissement.

> 💬 *« Est-ce que ce nom de groupe risque de poser problème ? »*

### Connaître les limites connues {#known-limitations}

*Connaissance · ⭐* — À lire avant de construire une mission. Pour la version de veaf-tools
installée : ce que les outils ne savent pas encore faire (et comment s'en passer), et les
comportements de DCS qui ne lèvent aucune erreur et sont faux quand même — un groupe en activation
différée visible des scripts, un `start_time` qui ne retarde pas un avion, un SAM sans radar d'alerte
allumé en permanence… Une limite corrigée n'est plus renvoyée à partir de la version qui la corrige.

> 💬 *« Lis les limites connues avant de commencer. »*

---

## 🏗️ Démarrer une mission de zéro

*Avant tout le reste : partir d'un **dossier vide** et obtenir un dossier de mission VEAF prêt à
l'emploi. L'IA télécharge les outils VEAF depuis GitHub, les installe dans le dossier, et pose les
fichiers par défaut du template choisi.*

### Créer un dossier de mission depuis zéro {#create-mission-folder}

*Dossier · ⭐* — En un appel, sur un **dossier vide** : l'IA récupère la dernière version des outils
VEAF (updater + `veaf-tools`) depuis la release GitHub, les installe, puis prépare le dossier avec
le template choisi. C'est l'**étape 0** avant d'ajouter des combat zones, QRA, etc. L'IA te
**demande d'abord quel template** tu veux :

- `minimal` — infrastructure + modules de base ;
- `standard` — le jeu quotidien (recommandé) ;
- `full` — tout, config avancée en exemples commentés.

Tu peux aussi préciser le **théâtre** (Caucasus, …) : l'IA génère alors une mission vierge de cette
carte directement, prête à recevoir des combat zones / QRA — **sans passer par DCS**.

> 💬 *« Crée-moi une nouvelle mission VEAF sur Caucasus dans ce dossier. »* (l'IA demande le
> template + le théâtre, puis installe et génère tout)

## 🎖️ Campagne multi-missions

*Une [campagne](CAMPAIGN.md) jouée mission après mission, chaque mission partant de ce que la précédente a laissé.
L'IA mène la boucle : lire la situation, appliquer la mission jouée, préparer la suivante, puis la concevoir avec les autres actions.*

### Lire où en est une campagne {#campaign-status}

*Campagne (dossier) · ⭐* — Les missions jouées, le propriétaire et la force de garnison de chaque zone, les réserves des deux camps, les objectifs atteints ou non, et ce qui a changé à la dernière mission.
C'est là-dessus que l'IA décide de l'intention de l'ennemi pour le tour suivant.

> 💬 *« Où en est la campagne du Caucase ? Qu'est-ce que les rouges vont tenter ? »*

### Appliquer une mission de campagne jouée {#campaign-apply}

*Campagne (dossier) · ⭐* — Une fois la mission jouée et son fichier d'état récupéré sur le serveur, l'IA le fusionne dans la campagne, joue le tour entre les missions (réserves, réparations, contre-attaques) et dit ce qui a changé.
Un fichier déjà appliqué, d'une autre campagne, ou qui saute une mission est refusé sans rien écrire.

> 💬 *« Voilà le fichier d'état de la mission 3, applique-le. »*

### Préparer la mission suivante d'une campagne {#campaign-next}

*Campagne (dossier) · ⭐* — L'IA prépare le dossier de la mission suivante à partir de l'état : chaque base à son propriétaire et ses slots dynamiques, les garnisons et leurs pertes, le module campagne activé.
Elle reçoit la partie factuelle du briefing stratégique en français et en anglais, puis conçoit la mission par-dessus et écrit la partie narrative.

> 💬 *« Prépare la mission 4 : les rouges contre-attaquent sur Senaki. »*

## 🗺️ Carte & coordonnées

*Pour se repérer et convertir sans lancer DCS. Les cartes DCS sont le monde réel projeté : l'IA
sait convertir entre les coordonnées locales DCS (x/y) et la lat/long.*

### Lire la carte {#read-the-map}

*Repérage · ⭐* — L'IA lit le **théâtre**, les **bullseyes** par coalition et les zones/groupes déjà
présents comme points de repère, avec la position de chacun (et la taille des groupes), pour placer les choses les unes par rapport aux autres.

> 💬 *« C'est quel théâtre ? Montre-moi les bullseyes et les zones existantes. »*

### Convertir des coordonnées {#convert-coordinates}

*Conversion · ◽* — Convertit une position entre **x/y DCS** et **lat/long** pour le théâtre de la
mission (l'IA lit le théâtre, tu n'as aucun paramètre à fournir).

> 💬 *« Ça fait quoi en lat/long, la position x=-291000 y=617000 ? »*

### Placer par nom de lieu réel {#geocode}

*Géocodage · ⭐* — Les cartes DCS sont le monde réel : l'IA résout un **nom de lieu** (« Batumi »,
« l'aéroport de Kobuleti »), éventuellement décalé (« à 10 km au nord de X »), en coordonnées DCS.
Par défaut via OpenStreetMap (gratuit) ; Google Maps si une clé est configurée. **Résultat
approximatif** (le terrain DCS approxime le réel) : l'IA te montre toujours le point résolu pour que
tu le valides. Les lieux **nommés** marchent ; le terrain vague (« les bois ») non.

> 💬 *« Mets un SAM à 15 km au sud-est de l'aéroport de Batumi. »* (l'IA géocode, décale, puis place)

### Connaître l'altitude du sol et le masquage par le relief {#terrain-elevation}

*Altitude du sol · ⭐* — Sans lancer DCS, l'IA donne l'**altitude du sol** sous une cible (pour le
briefing), le **sol le plus haut** le long de chaque branche d'une route (le plancher d'une
pénétration basse altitude), **combien de chaque branche un SAM voit** au-dessus du relief, et le
point culminant de chaque carré de 10 km de la grille F10. **Relief seul** : ni bâtiments, ni
pylônes, ni arbres, et une marge mesurée à ajouter, que l'IA te rappelle. Il faut d'abord relever le
théâtre **une fois** dans DCS (`.\veaf-tools.exe dcs terrain-sweep Syria`, moins de trois minutes) ;
sans ce relevé, l'IA te propose la commande.

> 💬 *« Ma route basse altitude passe-t-elle sous la couverture du SA-6 de Damas ? »*

## 🏁 Valider & construire

*La dernière étape : de la recette au `.miz` jouable, sans quitter l'assistant.*

### Valider une mission {#validate-mission}

*Dossier · ⭐* — Vérifie le dossier avant build (config, modules, références) et te liste erreurs et
avertissements. À faire avant de construire.

> 💬 *« Vérifie que ma mission est bonne avant de la construire. »*

### Compléter les statiques posés sans forme {#repair-static-shapes}

*Recette + construite · ◽* — Un statique posé par un outil avant la 6.26 peut manquer de la forme
(`shape_name`) que l'éditeur écrit ; DCS refuse certains types sans elle et l'objet n'existe jamais.
La validation les liste, cette action les complète toutes d'un coup.

> 💬 *« La validation se plaint des shape_name : répare-les. »*

### Construire le .miz jouable {#build-mission}

*Dossier · 🔥* — Construit le dossier en fichier `.miz` prêt à jouer dans DCS (lance `veaf-tools
build`). C'est l'aboutissement : dossier vide → contenu → **mission jouable**.

> 💬 *« Construis-moi la mission. »* · *« Construis la version de test locale. »*

## 🏗️ Composites — créer une fonctionnalité complète (une passe)

*Le cœur de l'objectif : d'une seule demande, l'IA pose une fonctionnalité VEAF entière sur les
**deux mondes** (source `src/mission` + `mission.yaml`) d'un **dossier de mission**. Durable : un
`veaf-tools mission build` ultérieur produit le `.miz`.*

### Créer une combat zone complète {#create-combat-zone}

*Recette (dossier) · 🔥* — En un appel : la zone de déclenchement, les groupes placés dedans
(nommés automatiquement pour être capturés par la zone) **et** le bloc `COMBATZONE` dans
`mission.yaml`. Tu décris, l'IA assemble. L'IA peut aussi faire **spawner des groupes VEAF
prédéfinis** à l'activation de la zone (SAM, convois…) plutôt que de figer des unités.

> 💬 *« Crée une combat zone “North” avec deux groupes de blindés ennemis. »*

### Créer une QRA complète {#create-qra}

*Recette (dossier) · 🔥* — En un appel : la zone protégée, les intercepteurs en **Late
Activation** (sur la bonne coalition) **et** la définition `QRA` dans `mission.yaml` (référençant
les groupes par nom exact). Tu dis l'avion, l'IA choisit le type et assemble. Les intercepteurs
sont créés **en vol**, avec le plein et un emport : donne-le, ou demande de le recopier d'un modèle
`veafSpawn-*` — un intercepteur désarmé n'intercepte rien.

> 💬 *« Crée une QRA rouge en Mirage 2000 sur la zone Nord, armée comme le modèle veafSpawn du Mirage. »*

### Créer une mission CAP à la demande {#create-cap}

*Recette (dossier) · ⭐* — En un appel : le groupe template `OnDemand-<nom>` en **Late
Activation** **et** l'entrée `cap_missions` dans `mission.yaml`. Le template est créé **en vol** avec
le plein ; donne-lui un second point et il tient un hippodrome entre les deux — sans, il ne patrouille
nulle part.

> 💬 *« Crée une CAP à la demande “Escort” avec deux F-15. »*

### Créer une opération (zones enchaînées) {#create-operation}

*Recette (dossier) · ◽* — Regroupe des **combat zones déjà créées** en une opération : l'activer fait apparaître **toutes** ses zones d'un coup, et chaque tâche devient l'objectif en cours quand celles dont elle dépend sont terminées — un objectif qui ne doit pas exister avant un autre est plutôt une zone chaînée.
Les joueurs la lancent depuis son menu F10, ou elle démarre seule avec la mission.
L'IA refuse une tâche qui ne nomme pas une zone de la mission.

> 💬 *« Fais une opération Tonnerre : d'abord CZ-Alpha, puis CZ-Bravo une fois Alpha tombée. »*

## 🛫 Bases & aérodromes

### Colorer une base et activer ses slots dynamiques {#colour-base}

*Recette (dossier) · 🔥* — Assigne un aérodrome à une coalition (bleu / rouge / neutre). La couleur
d'une base ne se change **pas** en posant une unité à côté : dis simplement « Mezzeh est bleu » et
l'IA colore l'aérodrome **durablement** puis **active ses slots dynamiques** (Dynamic Spawn), en
remplissant son entrepôt avec les avions dynamiques de la coalition au build. Pour une base qui
ne doit offrir **aucun** slot (une base ennemie, par exemple), dis-le : la couleur change, les slots
restent fermés.

> 💬 *« Mets la base de Mezzeh en bleu. »* · *« Passe Stendal en rouge, sans slots dynamiques. »*

### Lister les aérodromes d'un théâtre {#list-airfields}

*Lecture · ⭐* — Les bases d'une carte, avec leur nom exact, leur numéro DCS et leur position : de quoi
choisir les bases à colorer, ou placer quelque chose près de l'une d'elles, sans deviner un nom.
Marche aussi avant qu'une mission existe, en nommant la carte.

> 💬 *« Quelles bases y a-t-il en Allemagne de l'Est sur GermanyCW ? »*

### Donner aux bases leurs vraies fréquences radio {#airfield-channels}

*Recette (dossier) · ⭐* — Une radio tient une vingtaine de canaux, une carte compte des dizaines
d'aérodromes : il faut choisir. L'IA lit la mission, liste les bases que chaque camp tient (celles
avec des slots d'abord, rouges comprises), avec les fréquences et le TACAN **que DCS leur donne** —
celles que le pilote voit sur la vue F10 —, et te propose lesquelles mettre dans le plan radio. Elle
n'écrit que celles que tu choisis, et refuse d'inventer une fréquence : une base que DCS ne déclare
pas n'a pas de canal. Les canaux tactiques et de patrouille ne bougent pas.

> 💬 *« Quelles bases méritent un canal radio dans ma mission ? »* · *« Mets Batumi, Kutaisi et Vaziani dans le plan radio. »*

### Poser un FARP complet {#add-farp}

*Recette + construite · ⭐* — Un FARP qui sert vraiment : l'héliport, sa fréquence radio, son
indicatif, et l'entrepôt qui permet aux hélicoptères de s'y ravitailler et de s'y réarmer. Poser le
seul objet « FARP » ne suffit pas : personne ne peut s'en servir.

> 💬 *« Pose un FARP bleu à Fulda, sur 127,5 MHz. »*

### Poser un groupe aéronaval complet {#add-carrier}

*Recette + construite · ◽* — Un porte-avions prêt pour les opérations aériennes : le navire (et ses
escorteurs) en route à un cap et une vitesse, sa fréquence radio, son **TACAN**, son **ICLS**, et sur un
pont à brins d'arrêt son **Link 4** avec l'**ACLS** ; le ravitailleur embarqué et l'hélicoptère de
sauvetage que le module `CARRIER` cherche sous les noms exacts `<porte-avions> S3B-Tanker` et
`<porte-avions> Pedro` ; et l'entrepôt du navire, que le build garnit ensuite. Les places sur le pont se
posent ensuite comme un [vol au parking](#add-a-flight), en départ **sur le pont**.

> 💬 *« Pose un groupe aéronaval bleu au large de Batoumi, cap 270, TACAN 74X, ICLS 7. »*
> 💬 *« Mets quatre slots F/A-18C sur le pont du Stennis, moteurs coupés. »*

À savoir : le build ne garnit le pont qu'avec les appareils qui peuvent **décoller et apponter** sur ce
navire, d'après les données de DCS elles-mêmes — un F-14 sur le Stennis, pas sur le Tarawa ; un Harrier
et les hélicoptères sur les deux. Une liste d'appareils écrite à la main dans `warehouses.yaml` reste
respectée telle quelle. Pense à activer le module `CARRIER`.

## 🕰️ Réglages de la mission

### Dater la mission et régler son heure de départ {#mission-date}

*Recette + construite · ⭐* — La date et l'heure de départ, comme le panneau du temps de l'éditeur.
Une mission créée depuis zéro est datée de 2016 ; une mission guerre froide veut 1980. L'heure est
celle du théâtre, celle que DCS affiche. Les variantes météo de `versions.yaml` peuvent toujours
imposer la leur, variante par variante.

> 💬 *« Date la mission du 1er juin 1980, départ à 9 h 30. »*

### Placer le bullseye d'une coalition {#set-bullseye}

*Recette + construite · ⭐* — Le bullseye d'une coalition. Le build en tire le waypoint BULLSEYE de
chaque plan de vol, et les scripts VEAF annoncent les positions par rapport à lui : à placer tôt, sur
un repère connu.

> 💬 *« Mets le bullseye bleu sur Point Alpha, dans la trouée de Fulda. »*

### Écrire le briefing {#set-briefing}

*Recette + construite · ⭐* — Le nom de la mission, la situation et la tâche de chaque coalition ;
seuls les textes donnés changent. Une mission enregistrée par l'éditeur garde ces textes dans son
dictionnaire : l'IA les écrit là où la mission les range déjà. `${METAR}` et les autres variables du
briefing sont remplacées au build, variante par variante.

> 💬 *« Écris la situation : Europe centrale, juin 1980. Tâche bleue : tenir la trouée de Fulda. »*

### Régler la météo de la mission {#set-weather}

*Recette + construite · ⭐* — Nuages, vent, température, visibilité, pluie, brouillard, ou un METAR
entier. Une mission créée depuis zéro a ses nuages posés au sol : c'est à régler. Les variantes météo
de `versions.yaml` gardent la main, variante par variante.

> 💬 *« Mets un ciel fragmenté à 1 500 m, 12 °C, vent d'ouest 10 nœuds. »*

---

## 🔥 État de la mission

*L'IA regarde ce qui existe avant d'agir — comme toi qui ouvres l'arborescence de l'éditeur DCS
avant d'ajouter quelque chose.*

### Lister les groupes et zones {#list-groups-and-zones}

*Mission construite · 🔥* — L'IA te liste les groupes (nom, coalition, pays, catégorie) et les
zones de déclenchement (nom, position, rayon) présents dans la mission.

> 💬 *« Qu'est-ce qu'il y a comme groupes dans ma mission ? »*
> 💬 *« Liste-moi les zones de déclenchement. »*

### Inspecter les unités, leurs emports et leurs routes {#inspect-units}

*Mission construite · 🔥* — Un niveau de détail plus fin que la liste des groupes. L'IA te donne, pour
chaque appareil ou véhicule : son **type**, son **niveau d'IA**, sa **livrée**, son **indicatif**, son
numéro de flanc, sa position, son cap, son carburant — et son **emport, pylône par pylône**. Pour
chaque groupe : sa tâche, sa fréquence radio, s'il est masqué, s'il démarre moteurs coupés ou en
activation retardée, et sa **route complète** avec les tâches de chaque point de passage.

C'est ce qu'il faut lire **avant de demander une modification** : pour changer un emport, l'IA doit
d'abord voir celui qui est en place et sur quels pylônes.

> 💬 *« Qu'est-ce que porte le vol Colt, et sur quels pylônes ? »*
> 💬 *« Montre-moi la route du vol Enfield et ce qu'il doit faire à chaque point. »*

> ⚠️ **Sur une grosse mission, précise ce que tu cherches.** Une mission adoptée (type Foothold)
> contient des centaines de groupes, soit des mégaoctets de détail : demande un vol par son nom
> (« Colt » suffit), une coalition ou une catégorie. Dis-le si les routes ne t'intéressent pas, ça
> allège beaucoup la réponse.

### Lister les modules VEAF {#list-veaf-modules}

*Recette · 🔥* — L'IA lit la config source et te dit quels modules VEAF sont activés, désactivés,
ou configurés (avec leurs réglages).

> 💬 *« Qu'est-ce qui est activé dans ma mission ? »*
> 💬 *« Est-ce que CTLD est actif ? »* (ses réglages, eux, vivent dans `ctld-config.yaml`)

---

## ⭐ Ordre de bataille

### Ajouter un groupe {#add-a-group}

*Mission construite · ⭐* — L'IA insère un groupe terrestre / de véhicules : les unités (tu dis
quoi et combien), une position, et éventuellement un itinéraire (avec patrouille en boucle).
Ajouter deux fois crée deux groupes — comme deux placements dans l'éditeur. L'IA **nomme le
groupe correctement elle-même** selon ton intention : rattaché à une combat zone (préfixe de la
zone), en **Late Activation** pour une QRA, ou template de spawn (`veafSpawn-`).

> 💬 *« Ajoute une section de 3 T-72 en patrouille autour de ce point. »*
> 💬 *« Mets deux groupes de blindés dans la combat zone North. »*
> 💬 *« Place des intercepteurs Su-27 en Late Activation pour la QRA. »*

### Créer un slot joueur {#add-a-player-slot}

*Mission construite · ⭐* — L'IA crée une **place jouable** : c'est ce qu'il faut avant que quiconque
puisse voler une mission bâtie de zéro. Tu dis l'appareil, la position, et le type de départ — **en
vol** (altitude, vitesse, cap) ou **au sol** froid/chaud (là il faut fournir la place de parking).
Une place au sol sans emplacement est **refusée** plutôt que devinée : les emplacements de parking
sont une donnée capturée dans DCS, pas inventée. L'IA écrit pour toi la paire départ correcte et
règle la radio du groupe.

> 💬 *« Ajoute un slot A-10C au parking 43 de Kobuleti, départ à froid. »*
> 💬 *« Mets une place F-16 en vol à 15 000 ft au-dessus de la zone. »*

Comme dans l'éditeur, la place reçoit un **indicatif** (Enfield, Springfield… ; un numéro pour un pays
de l'Est), un **numéro de flanc** qu'aucun autre appareil de la mission ne porte, et les **leurres**
(chaff et flare) que l'éditeur donne à ce type — un slot en vol ne peut pas réarmer.

Une chose à savoir : un slot est en compétence **Client** (jouable aussi en solo) et n'est **jamais**
un template de spawn dynamique — c'est précisément ce réglage-là qui, laissé actif, fait qu'une place
existe dans le fichier mais n'apparaît pas dans la liste des slots.

### Poser un vol au parking {#add-a-flight}

*Mission construite · ⭐* — L'IA place un **vol** (un ou plusieurs appareils) sur les places de
parking d'un aérodrome que tu **nommes** — elle choisit elle-même les stands libres, sans que tu aies
à connaître leur numéro. Elle prend les places les plus proches de la piste, saute celles déjà prises,
et **refuse** si une place demandée est occupée (en te disant par quel groupe) ou si l'aérodrome n'a
pas de vraie place avion. Départ moteurs coupés ou chauds au parking, sur la piste, en vol, ou **sur
le pont** d'un porte-avions ([groupe aéronaval](#add-carrier)) — un appareil qui ne peut pas utiliser
ce pont est refusé. Chaque appareil reçoit ses leurres, un indicatif (Texaco pour un ravitailleur,
Overlord pour un AWACS) et un numéro de flanc unique dans la mission.

> 💬 *« Mets un deux-ship de F-16 au parking de Kobuleti. »*
> 💬 *« Ajoute quatre Su-25 au parking de Batoumi, moteurs chauds. »*
> 💬 *« Fais décoller une patrouille de F-15 depuis la piste d'Incirlik. »*

Les appareils sont en **IA par défaut** — utile pour du trafic ou des cibles. Un vol IA **n'apparaît
pas** dans l'écran « Choice of role » (qui ne liste que les places jouables) : pour t'y poser et le
piloter, demande explicitement des **slots joueur**. L'aérodrome doit avoir été **capturé** au
préalable (donnée de parking) ; sinon l'IA te le dit au lieu de deviner.

### Modifier un appareil ou un véhicule existant {#change-a-unit}

*Mission construite · ⭐* — Changer ce qui est **déjà** dans la mission, unité par unité : son
**emport** (pylône par pylône), ses **leurres** (chaff et flare), son **niveau d'IA**, sa **livrée**,
son **cap**, son **indicatif** et son **numéro de flanc**, son **nom**, sa **position**. Tu donnes le cap en degrés, l'IA fait la conversion. Seuls les réglages que
tu demandes changent, et l'IA te dit ce qu'il y avait avant.

> 💬 *« Donne au vol Colt un emport air-sol. »*
> 💬 *« Enlève les bombes du pylône 4 de Colt 1-1-1. »*
> 💬 *« Mets ce MiG en niveau Excellent et oriente-le au 270. »*
> 💬 *« Renomme l'indicatif de ce vol en Colt 2-3. »*

Trois choses à savoir, parce qu'elles évitent une surprise :

- **L'IA doit d'abord regarder** ([inspecter les unités](#inspect-units)) : elle désigne l'unité
  par son nom **exact**, pour qu'une modification ne parte jamais sur le mauvais groupe.
- **La livrée et les armes ne sont pas vérifiables** par l'outil : DCS affiche la peinture par
  défaut, ou retire une arme que l'appareil ne peut pas porter, **sans le dire**. L'IA te le
  rappellera ; c'est à vérifier dans l'éditeur.
- **Transformer une unité IA en slot joueur est refusé** (et l'inverse aussi) : ce n'est pas un
  niveau de compétence mais un slot multijoueur, qui apparaîtrait ou disparaîtrait de la liste des
  places disponibles.

### Déplacer, renommer ou reconfigurer un groupe {#change-a-group}

*Mission construite · ⭐* — Agir sur un groupe **entier** : le **déplacer**, le **renommer**, changer
sa **fréquence radio**, le passer en **Late Activation**, le **masquer** ou le laisser **moteurs
coupés**.

> 💬 *« Déplace cette batterie SAM de 5 km vers l'est. »*
> 💬 *« Renomme ce groupe selon la convention VEAF. »*
> 💬 *« Mets ce vol en Late Activation et moteurs coupés. »*
> 💬 *« Passe la fréquence de ce vol sur 305 AM. »*

Le déplacement est la partie qui demandait le plus de soin, et voici pourquoi :

- **Un groupe n'est pas un point.** Ce sont des unités en formation, plus éventuellement une route.
  L'outil déplace **toutes les unités, tous les points de passage et l'ancre du groupe** du même
  vecteur : sinon la formation se déforme, ou la route se détache des unités — et ça ne se voit qu'en
  vol.
- **Une distance et un cap sont calculés sur le globe**, avec la même mécanique que le placement par
  nom de lieu réel, pas en ajoutant des mètres à une coordonnée.
- ⚠️ **La nature du terrain à l'arrivée n'est pas vérifiable** au moment de la construction : un
  groupe terrestre peut se retrouver dans l'eau ou sur une pente sans que rien ne le signale. C'est
  aussi pour ça que le placement *à l'exécution* (spawn VEAF) sait éviter les villages et les forêts,
  lui. À vérifier dans l'éditeur.

Deux refus utiles : **renommer sur un nom déjà pris** est bloqué (deux groupes homonymes rendent
toute modification ultérieure ambiguë), et **un nom qui déclenche une convention VEAF réservée** l'est
aussi — par exemple préfixer un groupe du nom d'une combat zone, ce qui le fait *disparaître au
démarrage*. Si c'est justement ton intention, l'IA peut passer outre en le disant explicitement.
Enfin, **la fréquence est vérifiée face à ce que l'appareil peut réellement afficher** : hors plage,
l'éditeur DCS refuserait d'enregistrer la mission.

### Modifier la route d'un vol et ce qu'il y fait {#change-a-route}

*Mission construite · ⭐* — Ajouter, insérer, supprimer ou réordonner un **point de passage**, changer
son altitude, sa vitesse, son nom ou son type — et surtout lui donner une **tâche** : orbiter,
attaquer un groupe, bombarder un point, engager les cibles d'une zone, se poser, régler une fréquence,
ou boucler la route sur elle-même. Pour un **vol de soutien** : ravitailler (`tanker`), faire l'AWACS,
allumer un **TACAN** (canal, mode X/Y, indicatif), activer la liaison de données (EPLRS), avoir du
carburant illimité, ou **escorter** un autre groupe désigné par son nom. Pour une **balise radio** :
une unité qui **diffuse un son** en boucle sur sa fréquence, que l'hélicoptère retrouve au
radiocompas ([embarque le son](#add-sound) d'abord, et règle la fréquence juste avant).
Pour un **convoi**, chaque point peut suivre les **routes** ou couper à travers champs.

> 💬 *« Ajoute un point de passage après le troisième, à 20 000 pieds. »*
> 💬 *« Fais orbiter ce ravitailleur en hippodrome à 20 000 pieds, 300 nœuds. »*
> 💬 *« Mets une tâche d'attaque sur ce groupe au point 3. »*
> 💬 *« Boucle la patrouille du dernier point vers le deuxième. »*
> 💬 *« Fais de Texaco un ravitailleur, TACAN 30Y indicatif TXO, carburant illimité. »*
> 💬 *« Que les deux F-15 escortent Texaco. »*
> 💬 *« Fais de ce camion une balise sur 31 MHz FM qui diffuse beacon.ogg en boucle. »*
> 💬 *« Que le convoi suive la route jusqu'au troisième point. »*

Trois choses utiles à savoir :

- **Tu parles en pieds et en nœuds**, l'outil convertit (le fichier de mission, lui, est en mètres et
  en mètres par seconde). Les réponses te donnent les deux.
- **Les tâches sont une liste fermée**, chacune avec ses paramètres vérifiés. C'est volontaire : une
  tâche inventée est acceptée par le fichier, **ignorée par DCS**, et tu ne le découvres qu'en vol
  quand l'avion ne fait rien. Si une tâche te manque, elle s'ajoute — sur demande, jamais au hasard.
- **DCS refuse d'enregistrer une mission dont une route n'a aucun point à heure verrouillée.**
  Supprimer ou réordonner peut faire disparaître le seul point verrouillé : l'outil en reverrouille un
  et te le dit.

### Modifier une zone : la déplacer, la redimensionner, l'épouser au terrain {#change-a-zone}

*Mission construite · ◽* — Une combat zone VEAF **est** une zone de déclenchement. Jusqu'ici il fallait
la supprimer et la refaire pour l'ajuster ; maintenant elle se déplace, se redimensionne, se renomme,
change de forme, peut **suivre un porte-avions**, ou disparaître.

> 💬 *« Décale la combat zone de 3 km au nord. »*
> 💬 *« Fais suivre la ligne de crête à cette zone plutôt qu'un cercle. »*
> 💬 *« Agrandis la zone de la QRA. »*
> 💬 *« Attache cette zone au Stennis. »*

- **Une zone polygonale suit le terrain** : tu donnes trois points ou plus. Le runtime VEAF sait gérer
  n'importe quel polygone — mais l'éditeur DCS ne sait **dessiner** que des quadrilatères à 4 points,
  donc au-delà l'outil te prévient et il faut vérifier une fois dans l'éditeur.
- **Déplacer une zone polygonale emporte sa forme** (sinon la zone couvrirait un terrain que personne
  n'a choisi).
- ⚠️ **Renommer une zone ne met pas à jour ce qui la référence** : le `mission.yaml` de la combat zone
  et le préfixe du nom de ses groupes sont à reprendre à la main. L'outil te le rappelle.

### Dessiner sur la carte F10 {#draw-on-the-f10-map}

*Mission construite · ◽* — Une ligne de coordination, un couloir d'entrée, une boîte interdite, une
étiquette. **La raison de le faire ici plutôt que dans l'éditeur** : un dessin fait à la main est
**perdu** dès que la mission est reconstruite depuis son dossier, alors qu'un dessin posé par l'IA fait
partie de la recette.

> 💬 *« Trace la FSCL et nomme le couloir d'entrée sur la carte F10. »*
> 💬 *« Dessine une boîte interdite autour de Maykop. »*
> 💬 *« Déplace cette étiquette de 5 km au sud. »*

- **La couche décide qui voit le dessin** — rouge, bleu, neutre, commun, ou la couche de l'auteur — et
  ce n'est jamais un choix par défaut : un dessin sur la mauvaise couche est invisible pour ceux qui en
  ont besoin et visible par ceux qui ne devraient pas le voir.
- **Six formes sont disponibles** : la ligne (deux points ou plus, fermée pour délimiter une zone),
  le rectangle, l'étiquette de texte, le cercle (un rayon), l'ovale (deux axes et un angle) et le
  polygone libre rempli (trois points ou plus). La flèche et l'icône restent **refusées, avec une
  raison** — le contour d'une flèche demande une vérification en jeu, et une icône réclame un nom de
  fichier du jeu d'icônes de DCS qu'aucune donnée du dépôt ne liste — plutôt qu'un dessin deviné que
  l'éditeur supprimerait en silence.

---

## ⭐ Modules & réglages VEAF

### Activer / désactiver / configurer un module — recette {#configure-a-module-recipe}

*Recette · ⭐* — L'IA modifie la config source : elle active ou coupe un module (interrupteur
simple), ou pose un bloc de réglages complet (par ex. une combat zone avec ses zones, ses
messages…). **Durable** : survit à une reconstruction. Tes commentaires dans le fichier sont
préservés.

> 💬 *« Active CTLD dans ma mission. »*
> 💬 *« Ajoute une combat zone “Alpha” avec ces réglages… »*

### Activer / désactiver un module — mission construite {#enable-a-module-built}

*Mission construite · ⭐* — Bascule l'activation d'un module directement dans la mission déjà
bâtie, sans reconstruction. Pratique pour un test rapide (⚠️ écrasé à la prochaine
reconstruction depuis la recette).

> 💬 *« Désactive vite le module SPAWN dans le .miz pour tester. »*

### Changer le niveau de logs {#log-level}

*Recette + construite · ◽* — Règle le niveau de journalisation VEAF (erreur / avertissement /
info / debug / trace). Faisable sur la **recette** (durable) ou sur la **mission construite**
(rapide, écrasé au rebuild).

> 💬 *« Passe les logs VEAF en debug (dans la recette). »*

### Activer / désactiver la sécurité par mot de passe {#password-security}

*Recette + construite · ◽* — Active ou coupe le drapeau de sécurité VEAF (mot de passe requis
pour les commandes protégées). Côté **recette**, gère aussi les **hash de mots de passe**
(JTF / Mission Master) — ce que la mission construite ne fait pas.

> 💬 *« Coupe la sécurité mot de passe sur cette mission de test. »*

### Régler un paramètre VEAF précis {#veaf-parameter}

*Recette + construite · ◽* — Positionne un paramètre de configuration VEAF donné à une valeur
(côté recette : bloc `settings:` → `veaf.config.<clé>` ; côté construit : directement dans
`veaf-config.lua`).

> 💬 *« Mets tel paramètre VEAF à cette valeur. »*

---

## ◽ Zones & déclencheurs

### Ajouter une zone de déclenchement circulaire {#add-a-zone}

*Mission construite · ◽* — Insère une zone de déclenchement **circulaire** nommée (centre,
rayon). C'est la zone qu'une combat zone VEAF référence — combinée à l'ajout de groupes, elle
permet de poser une combat zone complète.

> 💬 *« Crée une zone de déclenchement “North” de 3 km ici. »*

### Ajouter un script au démarrage de la mission {#startup-script}

*Mission construite · ◽* — Ajoute un déclencheur « au démarrage » qui exécute un script — utile
pour outiller une mission **vanilla ou CTLD** avec du scripting sans passer par l'onglet Triggers
de l'éditeur DCS (Lua en ligne, ou un fichier `.lua` embarqué / chargé depuis le disque).

> 💬 *« Fais tourner ce bout de Lua au démarrage de la mission. »*
> 💬 *« Embarque et charge ce script .lua au lancement. »*

### Embarquer un son dans la mission {#add-sound}

*Recette + construite · ◽* — Copie un son (`.ogg` ou `.wav`) dans la mission et le déclare, comme
l'éditeur le fait quand tu choisis un fichier. C'est ce qu'il faut avant qu'une unité le
[diffuse](#change-a-route) — la balise radio d'une zone hélicoptère, un signal de détresse. Embarquer
deux fois le même fichier réutilise le premier.

> 💬 *« Embarque beacon.ogg et sos.ogg dans la mission. »*

### Ajouter une image au briefing {#briefing-picture}

*Recette + construite · ◽* — Copie une image (`.png` ou `.jpg`) dans la mission et l'ajoute au briefing d'un camp (bleu, rouge ou neutre), à la suite des images qu'il a déjà — comme l'éditeur quand tu choisis une image de briefing.
Évite de mettre la même image aux deux camps : un joueur dont le camp n'est pas connu du briefing (slot dynamique, par exemple) la verrait deux fois.

> 💬 *« Mets carte.jpg dans le briefing bleu. »*

---

## 🔧 Retouches avancées

### Rechercher-remplacer du texte dans les scripts {#search-replace}

*Mission construite · 🔧* — Remplacement texte ou expression régulière dans les fichiers Lua
embarqués de la mission (restreint aux scripts, jamais les tables brutes ni les binaires). Outil
de dépannage — à manier avec précaution.

> 💬 *« Remplace “debug” par “info” dans les scripts veaf-*. »*

---

## Et après ?

La feuille de route vise à ce que l'IA construise des fonctionnalités VEAF **complètes, en une
seule passe**, sur les deux mondes (le `.miz` et la recette `mission.yaml`) :

- 🧠 **L'IA gagne un « cerveau métier »** — accès aux types d'unités DCS, aux alias/raccourcis
  VEAF, aux conventions de nommage et à la config de chaque module. Elle nomme et configure
  correctement **elle-même** (tu donnes l'intention, pas les détails).
- ⭐ **Création de groupes contextuelle** — *« crée une CZ avec deux groupes de blindés »* ou
  *« une QRA en Mirage 2000 »* : l'IA choisit les types, nomme les groupes selon les conventions,
  gère la Late Activation, etc.
- 🔁 **Symétrie des cibles** — chaque réglage applicable à la recette **et** à la mission
  construite le sera sur les deux.
- 🏗️ **Actions « tout-en-un »** — `create_combat_zone`, `create_qra`, `create_cap_mission` :
  zone + groupes + config, d'un seul coup.

Cette page sera enrichie à chaque nouvelle capacité. Pour le détail technique, voir la
[doc développeur](../developer/mission-editing-mcp.md).
