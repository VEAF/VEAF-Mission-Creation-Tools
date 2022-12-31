# [![VEAF-logo]][VEAF website] Mission Creation Tools - installer l'environnement

This document is also available [in english](index.md)

## Introduction

Pour utiliser les outils VEAF Mission Creation Tools, il vous faudra un environnement bien spécifique.

Je vous rassure, c'est facile et on vous explique tout ici. Il suffit d'installer quelques outils.


## Installation des outils


Voici la liste des choses qu'il faudra mettre en place sur votre PC; nous alons détailler comment les installer dans la suite du document.

- LUA : il vous faudra un interpreter LUA, dans votre PATH, prêt à être appelé avec la commande `lua`
- 7zip : il vous faudra 7zip, ou un autre outil de compression ZIP, dans votre PATH, prêt à être appelé avec la commande `7zip`
- Powershell : vous aurez besoin de Powershell, et il faudra le configurer pour qu'il soit autorisé à exécuter des scripts (lire [cet article en anglais](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7.1)) ; dit simplement, vous devez lancer cette commande dans une fenêtre Powershell (en mode administrateur) : `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine`
- nodeJS : il vous faudra NodeJS,pour faire tourner les programmes javascript des outils de création de mission VEAF ; voir [ici (en anglais)](https://nodejs.org/en/)
- yarn : il vous faudra le gestionnaire de modules Yarn, pour récupérer automatiquement les outils de création de mission VEAF ; voir [ici (en anglais)](https://yarnpkg.com/)

**ATTENTION** : il ne faut pas faire à la fois *l'installation manuelle* et *l'installation par Chocolatey* !

### Installation avec Chocolatey

Ces outils nécessaires peuvent être installés facilement en utilisant *Chocolatey* (voir [ici (en anglais)](https://chocolatey.org/)).

**ATTENTION** : il ne faut surtout pas installer deux fois les outils, avec *l'installation manuelle* et *l'installation par Chocolatey* ! C'est **l'un ou l'autre** !

Pour installer Chocolatey, lancez cette commande dans une fenêtre Powershell (en mode administrateur) :

`Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))`

Une fois que *Chocolatey* est installé, vous pouvez installer les outils à l'aide de ces simples commandes dans une fenêtre *cmd* (en mode administrateur) :

- LUA : `choco install -y lua`
- 7zip : `choco install -y 7zip.commandline`
- nodejs : `choco install -y nodejs` ; puis fermez et réouvrez la fenêtre *cmd* (en mode administrateur)
- yarn : `npm install -g yarn`

Vous aurez quand même besoin de configurer Powershell pour qu'il soit autorisé à exécuter des scripts (lire [cet article en anglais](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7.1)) ; dit simplement, vous devez lancer cette commande dans une fenêtre Powershell (en mode administrateur) : 

`Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine`

### Installation manuelle

Si vous savez ce que vous faites, ou si vous détestez le chocolat (mais qui déteste le chocolat?), vous pouvez installer les outils requis manuellement.

Assurez-vous simplement que tous les outils listés ci-dessus sont fonctionnels avant de passer à la suite.

## Étape suivante - mettre en place un dossier de mission

Maintenant que tous les outils sont installés, il faut mettre en place un dossier qui contiendra les fichiers de votre mission.

Toutes les missions dynamiques scriptées avec les outils VEAF ont la même structure dans leur dossier :

![demo-mission-structure]

* *src* - tous les fichiers "source" de la mission - c'est à dire tout ce qui sert à la construire
* *src/mission* - la définition de la mission générée par l'éditeur de DCS (c'est un fichier lua qui est à l'origine compressé dans le fichier *.miz*)
* *src/scripts* - (optionnel mais presque toujours présent) les scripts que vous allez écrire pour configurer les modules VEAF, afin qu'ils se comportent comme vous le souhaitez pour votre mission
* *build.cmd* - la commande qui est responsable de créer le fichier compressé *.miz*, qui contient tous les fichiers lua définisant la mission, les scripts, les fichiers de configuration, etc.
* *extract.cmd* - la commande qui fait l'inverse de *build* : elle prend le fichier compressé *.miz* qui sort de l'éditeur de DCS, et en extrait tous les fichiers qui le composent dans les différents répertoires de *src*
* *package.json* - ce fichier fait le lien avec toutes les dépendances ; en particulier il permet d'aller chercher la dernière version des scripts VEAF automatiquement

Il y a de nombreuses façons de construire un tel dossier, avec cette structure ; parmi elles :

* faites un fork ou téléchargez une mission existante à partir d'un repository Github de la VEAF, telle que la [mission de démo][VEAF-demo-mission-repository], la [mission d'entrainement dans le Caucase][VEAF-Open-Training-Mission-repository], ou une mission de la [collection de missions VEAF][VEAF-Multiplayer-Missions-repository] (*facile*)
* utilisez le [convertisseur de mission existante][VEAF-mission-converter-repository] qui transforme une mission existante (un simple fichier *.miz*) en dossier VEAF (*pas trop difficile*)
* tout créer à partir de rien (*très avancé*)

## Contacts

Si vous avez besoin d'aide, ou si vous voulez suggérer quelque chose, vous pouvez :

* contacter [Zip][Zip on Github] sur Github
* aller consulter le [site de la VEAF][VEAF website]
* poster sur le [forum de la VEAF][VEAF forum]
* rejoinde le [Discord de la VEAF][VEAF Discord]


[Badge-Discord]: https://img.shields.io/discord/471061487662792715?label=VEAF%20Discord&style=for-the-badge
[VEAF-logo]: ../.images/logo.png?raw=true
[VEAF Discord]: https://www.veaf.org/discord
[Zip on Github]: https://github.com/davidp57
[VEAF website]: https://www.veaf.org
[VEAF forum]: https://www.veaf.org/forum

[VEAF-Mission-Creation-Tools-repository]: https://github.com/VEAF/VEAF-Mission-Creation-Tools
[VEAF-mission-converter-repository]:https://github.com/VEAF/VEAF-mission-converter
[VEAF-demo-mission-repository]: https://github.com/VEAF/VEAF-Demo-Mission
[VEAF-Open-Training-Mission-repository]: https://github.com/VEAF/VEAF-Open-Training-Mission
[VEAF-Multiplayer-Missions-repository]: https://github.com/VEAF/VEAF-Multiplayer-Missions

[demo-mission-structure]: ../.images/demo-mission-structure.png
