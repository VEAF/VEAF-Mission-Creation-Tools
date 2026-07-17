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
> du fichier concerné. Rien n'est écrasé sans copie.

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
| 1 | [Lister les groupes et zones déjà présents](#lister-les-groupes-et-zones) | État de la mission | Mission construite | 🔥 |
| 2 | [Lister les modules VEAF et leur réglage](#lister-les-modules-veaf) | État de la mission | Recette | 🔥 |
| 3 | [Ajouter un groupe terrestre / véhicules](#ajouter-un-groupe) | Ordre de bataille | Mission construite | ⭐ |
| 4 | [Activer / désactiver / configurer un module (recette)](#configurer-un-module-recette) | Modules & réglages | Recette | ⭐ |
| 5 | [Activer / désactiver un module (mission construite)](#activer-un-module-construite) | Modules & réglages | Mission construite | ⭐ |
| 6 | [Changer le niveau de logs](#niveau-de-logs) | Modules & réglages | Recette + construite | ◽ |
| 7 | [Activer / désactiver la sécurité par mot de passe](#securite-mot-de-passe) | Modules & réglages | Recette + construite | ◽ |
| 8 | [Régler un paramètre VEAF précis](#parametre-veaf) | Modules & réglages | Recette + construite | ◽ |
| 9 | [Ajouter une zone de déclenchement circulaire](#ajouter-une-zone) | Zones & déclencheurs | Mission construite | ◽ |
| 10 | [Ajouter un script au démarrage de la mission](#script-au-demarrage) | Zones & déclencheurs | Mission construite | ◽ |
| 11 | [Rechercher-remplacer du texte dans les scripts](#rechercher-remplacer) | Retouches avancées | Mission construite | 🔧 |
| 12 | [Lister les types d'unités DCS](#lister-unites-dcs) | Connaissance métier | — | ⭐ |
| 13 | [Lister les alias / raccourcis VEAF](#lister-alias-veaf) | Connaissance métier | — | ⭐ |
| 14 | [Expliquer les conventions de nommage](#conventions-nommage) | Connaissance métier | — | ◽ |
| 15 | [Renseigner sur un module VEAF](#decrire-module) | Connaissance métier | — | ◽ |
| 16 | [Vérifier un nom de groupe](#verifier-nom-groupe) | Connaissance métier | — | ◽ |
| 17 | [Créer une combat zone complète (une passe)](#creer-combat-zone) | 🏗️ Composites | Recette (dossier) | 🔥 |
| 18 | [Créer une QRA complète (une passe)](#creer-qra) | 🏗️ Composites | Recette (dossier) | 🔥 |
| 19 | [Créer une mission CAP à la demande (une passe)](#creer-cap) | 🏗️ Composites | Recette (dossier) | ⭐ |
| 20 | [Créer un dossier de mission depuis zéro](#creer-dossier-mission) | 🏗️ Démarrage | Dossier | ⭐ |
| 21 | [Lire la carte (repérage)](#lire-la-carte) | 🗺️ Carte & coordonnées | — | ⭐ |
| 22 | [Convertir des coordonnées (x/y ↔ lat/lon)](#convertir-coordonnees) | 🗺️ Carte & coordonnées | — | ◽ |
| 23 | [Placer par nom de lieu réel (géocodage)](#geocoder) | 🗺️ Carte & coordonnées | — | ⭐ |
| 24 | [Valider une mission avant build](#valider-mission) | 🏁 Valider & construire | Dossier | ⭐ |
| 25 | [Construire le .miz jouable](#construire-mission) | 🏁 Valider & construire | Dossier | 🔥 |

---

## 🧠 Connaissance métier (l'IA sait DCS + VEAF)

*L'IA s'appuie sur ces sources pour choisir les bons types d'unités, nommer correctement les
groupes et configurer les modules — sans que tu aies à connaître les détails techniques. Elles
sont lues depuis les données canoniques VEAF (générées / vendorisées), donc toujours à jour. Tu
peux aussi les interroger directement.*

### Lister les types d'unités DCS {#lister-unites-dcs}

*Connaissance · ⭐* — Types d'unités DCS (filtrables par catégorie ou par nom), depuis la base
générée par `update-dcs-data`.

> 💬 *« Quels chasseurs russes sont dispo ? »* · *« Montre-moi les SAM DCS. »*

### Lister les alias / raccourcis VEAF {#lister-alias-veaf}

*Connaissance · ⭐* — Le vocabulaire d'alias VEAF (`shilka`, `sa8`, …) pour le spawn d'unités et
de groupes composites (SAM sites, convois).

> 💬 *« C'est quoi l'alias pour une Shilka ? »* · *« Liste les groupes SAM tout faits. »*

### Expliquer les conventions de nommage {#conventions-nommage}

*Connaissance · ◽* — Les motifs de nommage réservés (combat zone, `veafSpawn-`, `#command`,
interpréteur…) que l'IA doit respecter pour ne pas casser une mission.

> 💬 *« Pourquoi mon groupe disparaît au démarrage ? »* (l'IA vérifie les conventions)

### Renseigner sur un module VEAF {#decrire-module}

*Connaissance · ◽* — Vérifie qu'un module existe, pointe vers sa page de doc, et dit s'il est
activé dans une mission donnée.

> 💬 *« Le module QRA, ça se configure comment ? »*

### Vérifier un nom de groupe {#verifier-nom-groupe}

*Connaissance · ◽* — Contrôle qu'un nom de groupe ne tombe pas dans un motif réservé
(préfixe `veafSpawn-`/`OnDemand-`, marqueurs `#command`/interpréteur, syntaxe QRA…) et, sur une
mission donnée, prévient du **piège de capture combat-zone**. L'IA s'en sert avant d'ajouter un
groupe et te relaie tout avertissement.

> 💬 *« Est-ce que ce nom de groupe risque de poser problème ? »*

---

## 🏗️ Démarrer une mission de zéro

*Avant tout le reste : partir d'un **dossier vide** et obtenir un dossier de mission VEAF prêt à
l'emploi. L'IA télécharge les outils VEAF depuis GitHub, les installe dans le dossier, et pose les
fichiers par défaut du template choisi.*

### Créer un dossier de mission depuis zéro {#creer-dossier-mission}

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

## 🗺️ Carte & coordonnées

*Pour se repérer et convertir sans lancer DCS. Les cartes DCS sont le monde réel projeté : l'IA
sait convertir entre les coordonnées locales DCS (x/y) et la lat/long.*

### Lire la carte {#lire-la-carte}

*Repérage · ⭐* — L'IA lit le **théâtre**, les **bullseyes** par coalition et les zones/groupes déjà
présents comme points de repère, pour placer les choses les unes par rapport aux autres.

> 💬 *« C'est quel théâtre ? Montre-moi les bullseyes et les zones existantes. »*

### Convertir des coordonnées {#convertir-coordonnees}

*Conversion · ◽* — Convertit une position entre **x/y DCS** et **lat/long** pour le théâtre de la
mission (l'IA lit le théâtre, tu n'as aucun paramètre à fournir).

> 💬 *« Ça fait quoi en lat/long, la position x=-291000 y=617000 ? »*

### Placer par nom de lieu réel {#geocoder}

*Géocodage · ⭐* — Les cartes DCS sont le monde réel : l'IA résout un **nom de lieu** (« Batumi »,
« l'aéroport de Kobuleti »), éventuellement décalé (« à 10 km au nord de X »), en coordonnées DCS.
Par défaut via OpenStreetMap (gratuit) ; Google Maps si une clé est configurée. **Résultat
approximatif** (le terrain DCS approxime le réel) : l'IA te montre toujours le point résolu pour que
tu le valides. Les lieux **nommés** marchent ; le terrain vague (« les bois ») non.

> 💬 *« Mets un SAM à 15 km au sud-est de l'aéroport de Batumi. »* (l'IA géocode, décale, puis place)

## 🏁 Valider & construire

*La dernière étape : de la recette au `.miz` jouable, sans quitter l'assistant.*

### Valider une mission {#valider-mission}

*Dossier · ⭐* — Vérifie le dossier avant build (config, modules, références) et te liste erreurs et
avertissements. À faire avant de construire.

> 💬 *« Vérifie que ma mission est bonne avant de la construire. »*

### Construire le .miz jouable {#construire-mission}

*Dossier · 🔥* — Construit le dossier en fichier `.miz` prêt à jouer dans DCS (lance `veaf-tools
build`). C'est l'aboutissement : dossier vide → contenu → **mission jouable**.

> 💬 *« Construis-moi la mission. »*

## 🏗️ Composites — créer une fonctionnalité complète (une passe)

*Le cœur de l'objectif : d'une seule demande, l'IA pose une fonctionnalité VEAF entière sur les
**deux mondes** (source `src/mission` + `mission.yaml`) d'un **dossier de mission**. Durable : un
`veaf-tools build` ultérieur produit le `.miz`.*

### Créer une combat zone complète {#creer-combat-zone}

*Recette (dossier) · 🔥* — En un appel : la zone de déclenchement, les groupes placés dedans
(nommés automatiquement pour être capturés par la zone) **et** le bloc `COMBATZONE` dans
`mission.yaml`. Tu décris, l'IA assemble.

> 💬 *« Crée une combat zone “North” avec deux groupes de blindés ennemis. »*

### Créer une QRA complète {#creer-qra}

*Recette (dossier) · 🔥* — En un appel : la zone protégée, les intercepteurs en **Late
Activation** (sur la bonne coalition) **et** la définition `QRA` dans `mission.yaml` (référençant
les groupes par nom exact). Tu dis l'avion, l'IA choisit le type et assemble.

> 💬 *« Crée une QRA rouge en Mirage 2000 sur la zone Nord. »*

### Créer une mission CAP à la demande {#creer-cap}

*Recette (dossier) · ⭐* — En un appel : le groupe template `OnDemand-<nom>` en **Late
Activation** **et** l'entrée `cap_missions` dans `mission.yaml`.

> 💬 *« Crée une CAP à la demande “Escort” avec deux F-15. »*

---

## 🔥 État de la mission

*L'IA regarde ce qui existe avant d'agir — comme toi qui ouvres l'arborescence de l'éditeur DCS
avant d'ajouter quelque chose.*

### Lister les groupes et zones {#lister-les-groupes-et-zones}

*Mission construite · 🔥* — L'IA te liste les groupes (nom, coalition, pays, catégorie) et les
zones de déclenchement (nom, position, rayon) présents dans la mission.

> 💬 *« Qu'est-ce qu'il y a comme groupes dans ma mission ? »*
> 💬 *« Liste-moi les zones de déclenchement. »*

### Lister les modules VEAF {#lister-les-modules-veaf}

*Recette · 🔥* — L'IA lit la config source et te dit quels modules VEAF sont activés, désactivés,
ou configurés (avec leurs réglages).

> 💬 *« Qu'est-ce qui est activé dans ma mission ? »*
> 💬 *« Est-ce que CTLD est actif ? Avec quels réglages ? »*

---

## ⭐ Ordre de bataille

### Ajouter un groupe {#ajouter-un-groupe}

*Mission construite · ⭐* — L'IA insère un groupe terrestre / de véhicules : les unités (tu dis
quoi et combien), une position, et éventuellement un itinéraire (avec patrouille en boucle).
Ajouter deux fois crée deux groupes — comme deux placements dans l'éditeur. L'IA **nomme le
groupe correctement elle-même** selon ton intention : rattaché à une combat zone (préfixe de la
zone), en **Late Activation** pour une QRA, ou template de spawn (`veafSpawn-`).

> 💬 *« Ajoute une section de 3 T-72 en patrouille autour de ce point. »*
> 💬 *« Mets deux groupes de blindés dans la combat zone North. »*
> 💬 *« Place des intercepteurs Su-27 en Late Activation pour la QRA. »*

---

## ⭐ Modules & réglages VEAF

### Activer / désactiver / configurer un module — recette {#configurer-un-module-recette}

*Recette · ⭐* — L'IA modifie la config source : elle active ou coupe un module (interrupteur
simple), ou pose un bloc de réglages complet (par ex. une combat zone avec ses zones, ses
messages…). **Durable** : survit à une reconstruction. Tes commentaires dans le fichier sont
préservés.

> 💬 *« Active CTLD dans ma mission. »*
> 💬 *« Ajoute une combat zone “Alpha” avec ces réglages… »*

### Activer / désactiver un module — mission construite {#activer-un-module-construite}

*Mission construite · ⭐* — Bascule l'activation d'un module directement dans la mission déjà
bâtie, sans reconstruction. Pratique pour un test rapide (⚠️ écrasé à la prochaine
reconstruction depuis la recette).

> 💬 *« Désactive vite le module SPAWN dans le .miz pour tester. »*

### Changer le niveau de logs {#niveau-de-logs}

*Recette + construite · ◽* — Règle le niveau de journalisation VEAF (erreur / avertissement /
info / debug / trace). Faisable sur la **recette** (durable) ou sur la **mission construite**
(rapide, écrasé au rebuild).

> 💬 *« Passe les logs VEAF en debug (dans la recette). »*

### Activer / désactiver la sécurité par mot de passe {#securite-mot-de-passe}

*Recette + construite · ◽* — Active ou coupe le drapeau de sécurité VEAF (mot de passe requis
pour les commandes protégées). Côté **recette**, gère aussi les **hash de mots de passe**
(JTF / Mission Master) — ce que la mission construite ne fait pas.

> 💬 *« Coupe la sécurité mot de passe sur cette mission de test. »*

### Régler un paramètre VEAF précis {#parametre-veaf}

*Recette + construite · ◽* — Positionne un paramètre de configuration VEAF donné à une valeur
(côté recette : bloc `settings:` → `veaf.config.<clé>` ; côté construit : directement dans
`veaf-config.lua`).

> 💬 *« Mets tel paramètre VEAF à cette valeur. »*

---

## ◽ Zones & déclencheurs

### Ajouter une zone de déclenchement circulaire {#ajouter-une-zone}

*Mission construite · ◽* — Insère une zone de déclenchement **circulaire** nommée (centre,
rayon). C'est la zone qu'une combat zone VEAF référence — combinée à l'ajout de groupes, elle
permet de poser une combat zone complète.

> 💬 *« Crée une zone de déclenchement “North” de 3 km ici. »*

### Ajouter un script au démarrage de la mission {#script-au-demarrage}

*Mission construite · ◽* — Ajoute un déclencheur « au démarrage » qui exécute un script — utile
pour outiller une mission **vanilla ou CTLD** avec du scripting sans passer par l'onglet Triggers
de l'éditeur DCS (Lua en ligne, ou un fichier `.lua` embarqué / chargé depuis le disque).

> 💬 *« Fais tourner ce bout de Lua au démarrage de la mission. »*
> 💬 *« Embarque et charge ce script .lua au lancement. »*

---

## 🔧 Retouches avancées

### Rechercher-remplacer du texte dans les scripts {#rechercher-remplacer}

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
