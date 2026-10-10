# VEAF Mission Creation Tools — 6.29.0

**Cette version est celle des campagnes multi-missions.**
Une campagne se joue maintenant mission après mission, chacune construite à partir de ce que la précédente a laissé : les garnisons et leurs pertes, le terrain pris, les réserves de chaque camp.
VMCT prépare la mission suivante, ses briefings et sa carte ; l'assistant IA peut mener toute la boucle.
La campagne *Kolkhida* l'a éprouvée en vol, et ce que l'escadrille y a trouvé est corrigé ici.
Autour d'elle, les convois savent enfin réagir à une embuscade, et la chasse ennemie se dimensionne au nombre de joueurs.

> ### ⚠️ Ce qui change dans vos missions
>
> **1. Les commandes F10 sécurisées (`+`) remarchent.**
> Depuis la 6.14.0, toute commande `+` était refusée à tous les pilotes, quel que soit leur niveau dans `veaf-pilots.txt`, sur toute mission où la sécurité était active.
> Elles s'exécutent de nouveau pour les pilotes qui ont le niveau requis.
> Une mission qui déclare `RADIO` initialise maintenant toujours `SECURITY`, et le `/secu elevate` que suggère un refus répond enfin.
> Pour couper la vérification de niveau, c'est `security: disabled: true` — ne pas déclarer `SECURITY` ne l'a jamais coupée.
>
> **2. Une entrée de menu F10 apparue en cours de mission va en fin de menu.**
> Le menu VEAF n'est plus reconstruit en entier à chaque changement, ce qui pouvait faire exécuter une autre commande que celle cliquée (voir plus bas).
> En contrepartie, une entrée qui apparaît après le premier affichage se range à la fin de son menu, sur sa dernière page, et non plus à sa place alphabétique ; une entrée déjà affichée ne change jamais de page.

---

## 🗺️ Campagnes multi-missions

Un dossier de campagne décrit dans `campaign.yaml` les zones, leurs liaisons, les objectifs et les réserves de chaque camp.
Les commandes `veaf-tools campaign init`, `next`, `apply` et `validate` déroulent la boucle, et les actions MCP `campaign_status`, `campaign_apply`, `campaign_next` et `campaign_briefing` permettent à l'assistant IA de la mener.
Voir [la page Campagne](https://veaf.github.io/documentation/latest/mission-maker/CAMPAIGN/).

**En vol**, le nouveau module `veafCampaign` :

- spawne la garnison de chaque zone, moins ses pertes, avec l'infanterie, les blindés et la défense aérienne d'une cible CAS de sa taille — environ 23 unités pour un avant-poste, 51 pour un aérodrome avec son SAM longue portée ;
- dessine la situation sur la carte F10 ;
- laisse un camp prendre une zone neutre en la tenant au sol ;
- lance des **convois d'assaut** : après `rules.assault_seconds` (600 s, plus tôt au-delà de quatre joueurs), chaque camp qui tient une zone voisine envoie par la route un convoi blindé — 4 chars et véhicules de combat d'infanterie depuis un avant-poste, 6 depuis un aérodrome — payé unité par unité sur sa réserve ; le convoi qui prend la zone devient sa garnison, et les joueurs bleus peuvent en envoyer depuis **Campaign → Assaults** ;
- prévient l'autre camp d'un convoi plus tard, comme du renseignement (`rules.intel_seconds`, 20 minutes par défaut) ;
- écrit pendant le vol et à la fin un fichier d'état dans `Saved Games`, et le débriefing de la mission en français et en anglais : terrain qui a changé de mains, pertes de chaque camp zone par zone et type par type, décor détruit, objectifs.

**Entre deux missions**, le fichier d'état est fusionné et un tour se joue selon des règles fixes : la logistique alimente les réserves, les réserves réparent les garnisons, une zone neutre bordée par un seul camp est reprise par lui.
`campaign next` prépare alors le dossier de la mission suivante :

- ses bases, ses slots dynamiques, et les objectifs de la mission comme waypoints des joueurs ;
- une date, une heure et une météo propres à la mission : le lendemain de la dernière mission jouée, l'heure calculée sur le terrain de la campagne, une météo tirée avec le sol visible ;
- l'opposition calibrée sur la taille attendue de l'escadrille (`players: 5-7` dans `campaign.yaml`, `--players 6` pour ce soir) ;
- le nom `Campaign_<campagne>_Mission_<NN>_<titre>_NoMizedit`, l'ATC coupé et la sécurité du serveur.

**Deux briefings au format PowerPoint**, qui s'importent dans Google Slides :

- `briefing-campagne.pptx`, d'après le modèle VEAF : situation stratégique et militaire, carte sur OpenStreetMap, mission et intention, objectifs, concept d'opération, règles d'engagement, tâches de la mission. Les faits sont générés ; la prose s'écrit dans `briefing.yaml`, à la main ou par l'assistant. L'ennemi n'y est jamais chiffré : seulement du renseignement, de fiabilité inégale.
- `briefing-mission.pptx`, lu dans la mission construite : situation générale, ATO, carte tactique et un zoom par objectif, déroulé, plan de fréquences, coordonnées des objectifs, plan de navigation.

Pas encore rejoué d'une mission à l'autre, bien qu'enregistré : le décor détruit, les missiles restants des SAM, les stocks des entrepôts.

> Un dossier de mission rafraîchi par `campaign next` perd son `security.disabled` et ses mots de passe : couper la sécurité dans une copie de test, jamais dans la campagne.

---

## 🚚 Des convois qui ne meurent pas dans une embuscade

Laissé à DCS, un convoi traverse une embuscade à pleine vitesse sans tirer une cartouche (mesuré).
Tout `_spawn convoy`, tout groupe listé sous `GROUNDAI.convoys` ou confié par `_gc <nom>, convoy` surveille maintenant devant lui.
Au premier ennemi en vue ou au premier tir reçu, il se sépare : les véhicules non armés fuient aussitôt, les véhicules armés engagent, ou se replient eux aussi s'ils sont surclassés.

- Il parle à la radio comme un équipage, sous un indicatif (Mule, Bison, Yak…) qui est aussi son nom pour `_gc`, et un marqueur F10 le montre pendant le contact.
- Assez fort, il signale le contact puis repart seul une fois la menace disparue, ses véhicules non armés de nouveau en colonne.
- Surclassé, il appelle à l'aide comme des troupes au contact — fumigène rouge sur l'ennemi, vert sur lui, en voix sur la garde quand SRS est configuré — puis se replie vers un lieu ami à l'abri du relief ou d'une ville, et attend `_gc <convoi>, retreat`, `hold` ou `resume`.
- Sans joueur de son camp connecté, il repart seul au bout de 5 minutes plutôt que d'attendre un ordre que personne ne donnera.
- Un fantassin vu à 3 km ne le fait plus fuir : une unité au sol compte pour sa force réelle, et un obus n'est jamais une menace.

---

## ✈️ La chasse ennemie à la taille des joueurs

Le nouveau bloc `opposition:` de `mission.yaml` donne à la mission un niveau : le nombre d'avions joueurs pour lequel la chasse ennemie est dimensionnée.
Il se règle à la génération, en vol depuis le menu radio **Opposition** (en un clic, de 1 à 8 joueurs en CAP) ou le marqueur `_opposition`, ou suit les joueurs : `follow: air_to_air` ne compte que les joueurs en l'air qui emportent un missile air-air à guidage radar.
Une hausse est prise tout de suite, une baisse au bout de cinq minutes stables, et chaque changement est annoncé.

- Une QRA avec `scale_with_opposition: true` décolle au palier du niveau quand il dépasse le nombre d'intrus dans sa zone.
- Le menu de difficulté d'une mission de combat gagne une entrée **Auto scale** : un groupe ennemi pour deux joueurs.

Et les QRA elles-mêmes :

- **Une QRA décolle au palier pour lequel elle a été écrite.** Le palier retenu était le dernier visité dans l'ordre aléatoire des tables Lua, pas le plus grand qui convient : des paliers 5, 1, 3 donnaient à 6 intrus le palier de 3.
  Un `random_pick` pouvait aussi tirer deux fois le même groupe ; le tirage est maintenant sans remise.
  Un palier sans `random_pick` envoie désormais **tous** les groupes qu'il liste : ajouter `random_pick: 1` pour garder l'ancien tirage d'un seul groupe.
- **Une QRA qui part de la piste décolle**, au lieu de disparaître 5 s plus tard ; les vagues aériennes avaient le même défaut. Compter 25 à 35 s entre l'alerte et le décollage.
- `rearm_while_occupied: true` réarme une QRA détruite sans attendre que sa zone soit vide.

---

## 📻 Le menu radio exécute la commande cliquée

Un menu F10 resté ouvert pendant qu'un joueur rejoignait, ou qu'une zone ou une mission changeait, pouvait exécuter une autre commande que celle cliquée : DCS recycle le numéro interne d'une entrée supprimée et ne rafraîchit pas un menu ouvert.
Le menu VEAF est maintenant mis à jour sur place, et le CTLD embarqué fait de même (voir plus bas).
L'option de diagnostic `RADIO.menu_stats` écrit dans `dcs.log`, à chaque rafraîchissement, ce que le menu a gagné et perdu, pour voir s'il grossit sur une mission multijoueur.

---

## 🤖 L'assistant IA

- **Toute IA compatible MCP peut construire une mission VEAF**, pas seulement Claude Code et Gemini CLI : la nouvelle action `describe_authoring_guide` lui donne les conventions de nommage et l'ordre de travail. [Installer l'assistant IA](https://veaf.github.io/documentation/latest/mission-maker/AI_ASSISTANT_INSTALL/) explique comment brancher un autre client, Claude Desktop par exemple.
- **L'assistant n'écrit plus deux groupes du même nom** : toute action qui crée un groupe refuse un nom de groupe ou d'unité déjà pris, et `remove_group` ne supprime plus d'un coup tous les homonymes.
- `create_qra` avec `loadout_from` copie n'importe quel emport.
- **Les positions d'aérodromes viennent de la base de référence `dcs-world-schema`** : le centre des pistes, à environ un kilomètre de l'ancien point ; FOB Clark (Afghanistan) n'est plus en 0°N 0°E.
- Un vol de Biélorussie, RDA, Yougoslavie, Ossétie du Sud ou des Insurgés reçoit un indicatif numérique, comme dans l'éditeur de mission.

---

## 🔧 Autres correctifs

- **Un serveur sans clés `SRS_*` dans `SERVER_CONFIG` ne plante plus la voix radio** : la mission reste muette et le dit dans le log.
- **Un plan de vol de `waypoints.yaml` prend ses waypoints par clé, et un waypoint garde son `name:`** : `POTI: "POTI_LOW"` menait sans rien dire à `POTI`. Un plan accepte maintenant une liste de clés, et le build avertit quand une valeur nomme un autre waypoint.
- **La ligne « modules actifs » du build nomme CTLD, CSAR et les autres scripts communautaires**, qui étaient bien injectés mais n'apparaissaient pas.

---

## 📘 Documentation

- **Les principales portes d'entrée sont sur le premier écran** : la page d'accueil s'ouvre sur des cartes « Je veux… » — voler, découvrir VMCT, ma première mission, créer avec une IA, reprendre une mission, obtenir de l'aide.
- **Le tutoriel va au-delà du premier vol** : choisir la langue de l'outil, remettre la sécurité pour le serveur avec un profil de build `TEST`, mettre à jour les outils et savoir pourquoi reconstruire ensuite.
- **Un nouveau piège DCS documenté** : un hélicoptère client placé sur un parking est installé ailleurs, jusqu'à 1,2 km plus loin, quand le joueur prend le slot ; un départ au sol est installé là où il est posé.

---

## 📦 Composants embarqués

- **CTLD `2.0.0-rc13`** : crates, troupes et JTAC sont créés sous un pays de la coalition de l'appareil qui les demande — une campagne sous CJTF Blue et CJTF Red n'obtenait aucune crate. Son menu F10 ne reconstruit plus que ce qui change.
- L'exécutable passe de 40,7 à 45,4 Mo, pour générer les briefings PowerPoint.

---

## 🙏 Merci

Aux copains de la VEAF, qui ont volé, cassé et raconté la mission 1 de *Kolkhida* — une bonne part de cette version vient de leurs retours.
Et à Fulgas pour CTLD, et pour la rc13 qui a rendu ses crates aux campagnes.
