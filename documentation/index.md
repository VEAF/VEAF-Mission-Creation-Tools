---
title: Outils de Création de Missions VEAF - documentation
description: Outils de Création de Missions VEAF - documentation pour les créateurs de missions, les pilotes et les programmeurs
---

-----------------------------

Navigation : vous êtes à la racine du site.

-----------------------------

Vous trouverez votre bonheur :
- dans [la table des matières](./ref_toc.md)
- dans [l'index](ref_index.md)
- dans [la feuille de route pour les créateurs de missions](./roadbook/road_missionmaker.md)
- dans [la feuille de route pour les pilotes](./roadbook/road_pilot.md)
- dans [la feuille de route pour les programmeurs](./roadbook/road_programmer.md)

-----------------------------

🚧 **ATTENTION TRAVAUX** 🚧

Cette documentation est en cours de mise en place, et remplacera bientôt [la documentation existante](https://veaf.github.io/documentation/) ; cette dernière version n'était pas encore terminée non plus, mais vous pourrez trouver le complément dans l'[ancienne documentation](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/master/old_documentation/_index.md).

-----------------------------

# Table des Matières

Vous pourrez trouver tous les sujets documentés:

- classés par thèmes dans la [table des matières]
- classés par ordre alphabétique dans l'[index des pages]

# Introduction

Les Outils de Création de Missions VEAF fournissent des outils et des scripts conçus pour créer, partager et maintenir facilement des missions dynamiques.

Ils regroupent

* des outils pour manipuler les fichiers de mission DCS et les serveurs
* les scripts de mission VEAF (organisés en modules)
* les hooks de serveur VEAF
* certains scripts de la communauté, parfois édités par VEAF (par exemple, CTLD, MiST)
* un workflow facile de création, d'édition et de publication de missions
* des outils pour soutenir ce workflow, y compris un convertisseur qui construit une mission dynamique à partir d'une mission statique existante
* cette documentation

Nos dépôts GitHub :

* le [dépôt principal][VEAF-Mission-Creation-Tools-repository] contient toutes les sources et la base de documentation
* le [convertisseur de mission][VEAF-mission-converter-repository] peut être forké ou téléchargé pour injecter les scripts et outils dans une mission existante
* la [mission de démonstration][VEAF-demo-mission-repository] (encore une fois, fork ou téléchargement) est une petite mission simple qui utilise certaines des dernières fonctionnalités des outils
* la [mission d'entraînement Caucasus VEAF][VEAF-Open-Training-Mission-repository] (fork ou téléchargement) est un bon exemple de travail des scripts dans une mission complexe
* le [dépôt de missions multijoueurs VEAF][VEAF-Multiplayer-Missions-repository] contient des missions que nous avons jouées avec la VEAF (certaines peuvent être anciennes et obsolètes !)

# De quoi ai-je besoin pour commencer ?

Vous devrez configurer un environnement, sur votre PC, avec des logiciels spécifiques (gratuits).

Lisez cette [page](./ref_404.md) pour plus d'informations.

# Quels outils sont disponibles et comment les utiliser ?

Les Outils de Création de Missions VEAF fournissent de nombreux outils et scripts.

La plupart d'entre eux sont destinés à être utilisés dans le pipeline de construction de mission (c'est-à-dire par un créateur de mission travaillant sur une mission, lisez la [documentation du créateur de mission](./ref_404.md)), mais certains peuvent être utilisés comme outils autonomes :
- le [normaliseur de dictionnaire LUA](./ref_404.md) qui facilite la comparaison des fichiers LUA
- l'[Injecteur de Météo](./ref_404.md) qui peut générer plusieurs fichiers de mission avec des heures de début et des conditions météorologiques différentes à partir d'un modèle
- le [Sélecteur de Mission](./ref_404.md) qui sélectionne une mission de départ pour votre serveur dédié à partir d'une liste de missions et d'un calendrier.

# Comment utiliser les scripts VEAF dans une mission que je veux concevoir ?

Veuillez lire la [documentation du créateur de mission](./ref_404.md).

Pour ceux qui recherchent un démarrage rapide, fork ou téléchargez le [convertisseur de mission](https://github.com/VEAF/VEAF-mission-converter) et suivez les instructions du fichier `readme.md`. Vous apprendrez comment utiliser les Outils de Création de Missions VEAF dans votre propre mission existante.

Vous pouvez également fork ou télécharger la [mission de démonstration](https://github.com/VEAF/VEAF-Demo-Mission) pour voir ce qui peut être fait (généralement seules les dernières fonctionnalités sont démontrées ici), et la [mission d'entraînement Caucasus VEAF](https://github.com/VEAF/VEAF-Open-Training-Mission) qui est une mission d'entraînement très complexe, ouverte et dynamique qui utilise beaucoup de fonctionnalités.

# Comment contribuer à ce merveilleux dépôt ?

Tout d'abord, merci !

Nous accueillons toujours de l'aide et de nouvelles idées.

Veuillez toujours utiliser des branches et des pull requests ! Commencez par forker le dépôt [VEAF-Mission-Creation-Tools](https://github.com/VEAF/VEAF-Mission-Creation-Tools), créez une branche, hackez et publiez votre travail.

# Je veux aider à maintenir la documentation !

Le moyen le plus simple de le faire est de modifier les fichiers directement sur le site Web de Github.

Mais vous pouvez également forker le [dépôt principal][VEAF-Mission-Creation-Tools-repository].

# J'ai besoin d'ajouter de nouvelles fonctionnalités ou de corriger des bugs dans les scripts !

Veuillez lire la [documentation du programmeur](./programmer/index.md).

-----------------------------

# Contacts

Si vous avez besoin d'aide ou si vous souhaitez suggérer quelque chose, vous pouvez

* contacter **Zip** sur [GitHub][Zip on Github] ou sur [Discord][Zip on Discord]
* aller sur le [site Web VEAF]
* poster sur le [forum VEAF]
* rejoindre le [Discord VEAF]

-----------------------------

Réalisé et maintenu par la Virtual European Air Force, une communauté française de pilotes DCS.

[![VEAF-logo]][VEAF website]
[![Badge-Discord]][VEAF Discord]

-----------------------------

[table des matières]: ./ref_toc.md
[index des pages]: ./ref_index.md

[Badge-Discord]: https://img.shields.io/discord/471061487662792715?label=VEAF%20Discord&style=for-the-badge
[VEAF-logo]: ./images/logo.png


[Discord VEAF]: https://www.veaf.org/discord
[Zip on Github]: https://github.com/davidp57
[Zip on Discord]: https://discordapp.com/users/421317390807203850
[site Web VEAF]: https://www.veaf.org
[forum VEAF]: https://www.veaf.org/forum

[VEAF-Mission-Creation-Tools-repository]: https://github.com/VEAF/VEAF-Mission-Creation-Tools
[VEAF-mission-converter-repository]:https://github.com/VEAF/VEAF-mission-converter
[VEAF-demo-mission-repository]: https://github.com/VEAF/VEAF-Demo-Mission
[VEAF-Open-Training-Mission-repository]:https://github.com/VEAF/VEAF-Open-Training-Mission
[VEAF-Multiplayer-Missions-repository]: https://github.com/VEAF/VEAF-Multiplayer-Missions
