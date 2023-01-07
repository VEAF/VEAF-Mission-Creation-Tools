# Outils de création de missions - application veaf-tools [!-[VEAF-logo]] [site web de la VEAF]

# /!\N- **TRADUCTION DEEPL.COM** /!\N- *

Cette traduction est réalisée par DeepL.com, un service de traduction automatique. Elle n'est pas parfaite, mais elle est suffisamment bonne pour vous aider à comprendre le contenu de la page.

En cas de doute, référez-vous à la [version originale en anglais](./veaf-tools.md).

# /!\N- **TRAVAIL EN COURS** /!\N- *
La documentation est en train d'être retravaillée, pièce par pièce. 
En attendant, vous pouvez consulter l'[ancienne documentation](../ancienne_documentation/_index.md).

**RETOURNER À L'INDEX DES OUTILS](index.md)**.

## Introduction

Cette application nodeJS est une collection d'outils qui peuvent être utilisés pour manipuler les missions.

Pour l'instant, il contient les outils suivants :
- Injecteur météo
- sélecteur de mission

### Injecteur météo

L'injecteur météo est un outil qui transforme un fichier de mission unique en une collection de missions, avec le même contenu mais des conditions météorologiques et de départ différentes.

Il peut être utilisé pour injecter une définition météo DCS prédéfinie, lire un METAR et générer une mission avec la météo correspondante, ou même utiliser la météo du monde réel.

Il peut également créer différentes dates et heures de départ pour la mission, soit avec des valeurs absolues (par exemple le 26/01/2023 à 14:20), soit avec des "moments" prédéfinis (par exemple 2 heures après le coucher du soleil).

C'est un outil très utile à utiliser avec un serveur qui fonctionne 24 heures sur 24 et 7 jours sur 7 et qui a besoin d'avoir des conditions météorologiques différentes chaque fois qu'il démarre la même mission.

[Vidéo de démonstration] [veaftools-injectall-demo]

### Sélecteur de mission

Le sélecteur de mission est utilisé pour démarrer un serveur dédié avec une mission spécifique, en fonction d'un planning défini dans un fichier de configuration.

## Installation

Il s'agit d'un outil autonome, qui ne nécessite pas d'environnement VEAF Mission Creation Tools spécifique (tel que décrit [ici] (..\environment\index.md)).

Il est donc très facile à installer sur un serveur, ou sur votre propre ordinateur.

***Nota bene : ce chapitre est également disponible sous forme de [tutoriel vidéo][install-chocolatey-nodejs-veaftools]***

Vous devrez installer ces outils sur votre ordinateur :

- *nodeJS* : vous avez besoin de NodeJS pour exécuter les programmes javascript dans les outils de création de missions VEAF ; voir [ici](https://nodejs.org/en/)
- *yarn* : vous avez besoin du gestionnaire de paquets Yarn pour récupérer et mettre à jour les outils de création de missions VEAF ; voir [ici](https://yarnpkg.com/)

### Installer les outils en utilisant Chocolatey

Les outils nécessaires peuvent être facilement installés en utilisant *Chocolatey* (voir [ici](https://chocolatey.org/)).

Pour installer Chocolatey, utilisez cette commande dans une invite Powershell élevée (admin) :

``powershell
Set-ExecutionPolicy Bypass -Scope Process -Force ; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072 ; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
```

Après avoir installé *Chocolatey*, installez NodeJS en tapant cette simple commande dans une invite de commande :

``cmd
choco install -y nodejs
```

Ensuite, fermez et rouvrez l'invite de commande.

### Installer l'application veaf-tools

Dans une invite de commande, allez dans le répertoire où vous voulez installer l'application veaf-tools, et tapez :

``cmd
npm install -g veaf-mission-creation-tools
```

Ensuite, fermez et rouvrez l'invite de commande.

## Utilisation générale de l'application

Pour lancer les outils VEAF, il suffit de taper `veaf-tools` dans une invite de commande.

[!veaftools-options]] [veaftools-options]

## Utilisation de l'injecteur Weather

L'injecteur Weather est en fait deux commandes de l'application veaf-tools.

La commande `inject` va injecter la météo dans le fichier de mission que vous avez spécifié, et créer un nouveau fichier de mission avec la météo et les conditions de départ que vous avez spécifiées dans les options de la ligne de commande.

Tapez `veaf-tools inject --help` pour obtenir de l'aide :

[!veaftools-inject-options]] [veaftools-inject-options]

La commande `injectall` va lire un fichier de versions contenant plusieurs conditions météorologiques et de départ, et les injecter dans le fichier de mission source, créant ainsi une collection de fichiers de mission cibles.

Tapez `veaf-tools injectall --help` pour obtenir de l'aide :

[!veaftools-injectall-options]][veaftools-injectall-options]

### Options

#### Options obligatoires de la ligne de commande

Les options de ligne de commande suivantes sont obligatoires pour les commandes `inject` et `injectall` ; n'utilisez pas le nom de l'option, ce sont des arguments positionnels (c'est-à-dire que vous devez les spécifier dans l'ordre où elles sont listées ici) :

- `--source` : le chemin vers le fichier de mission dans lequel injecter le temps.

- `--target` : le chemin vers le fichier de mission à créer avec la météo injectée. Avec la commande `injectall`, "${version}" sera remplacé par le nom de la version générée.

De plus, la commande `injectall` doit avoir l'option `--configuration` qui pointe vers le fichier de configuration des versions. Encore une fois, c'est un argument positionnel, donc n'utilisez pas le nom de l'option.

Exemple :

``cmd
veaf-tools inject source.miz target.miz 
```

ou

``cmd
veaf-tools injectall source.miz target-${version}.miz versions.json
```

#### Options de ligne de commande facultatives

Les options de ligne de commande suivantes sont optionnelles, et sont disponibles pour les commandes `inject` et `injectall` :

- `--verbose` : si cette option est mise à *true*, l'outil donnera plus d'informations sur ce qu'il fait.

- `--quiet` : si la valeur est *true*, l'outil donnera moins d'informations sur ce qu'il fait. 

- `--nocache` : s'il est défini à *true*, l'outil n'utilisera pas le cache pour les fichiers météo. Ceci est utile si vous voulez forcer l'outil à récupérer la météo depuis l'API CheckWX à chaque fois qu'il s'exécute.

#### Options communes

La commande `injectall` appelle finalement le même code que la commande `inject` pour injecter le temps dans un fichier de mission cible, avec les options définies dans chaque cible du fichier de configuration. 

Par conséquent, toutes les options qui peuvent être définies dans chaque cible du fichier de configuration pour la commande `injectall`, peuvent également être définies comme options de ligne de commande pour la commande `inject`.

Voici les options disponibles, avec à chaque fois l'option de la ligne de commande suivie de l'option cible correspondante :

- `--real`, `realweather` : si la valeur est *true*, la météo sera récupérée du monde réel en utilisant CheckWX (voir ["Injecting real world weather"](#injecting-real-world-weather)).

- `--clearsky`, `clearsky` : si la valeur est *true*, et si la météo réelle est récupérée, la couverture nuageuse sera limitée à 3 octas. Cela permet d'avoir une météo réelle, mais suffisamment claire pour un soutien aérien rapproché.

- `--metar`, `metar` : s'il s'agit d'un [METAR] valide (https://en.wikipedia.org/wiki/METAR), la météo sera générée à partir du METAR analysé (par exemple *UG27 221130Z 04515KT +SHRA BKN008 OVC024 Q1006 NOSIG*).

- `--start`, `time` : l'heure de début de la mission en secondes après minuit

- `--variable`, `variableForMetar` : le nom de la variable qui sera remplacée par le METAR récupéré de CheckWX ; c'est une fonction utile pour montrer la météo dans le briefing.

- `--weather`, `weatherFile` : le chemin vers le fichier météo DCS à utiliser comme définition statique du temps.

- `--dontSetToday`, `dontSetToday` : si la valeur est *true*, la date de la mission ne sera pas fixée à la date du jour.

- `--dontSetTodayYear`, `dontSetTodayYear` : si elle est définie sur une année valide, et que dontSetToday est défini sur `false`, l'année de la mission sera définie sur l'année spécifiée tandis que le reste de la date sera défini sur la date du jour.

### Fichier des versions

Le fichier des versions est un fichier JSON qui contient les conditions météorologiques et de départ que vous souhaitez injecter dans le fichier de la mission, lorsque vous utilisez la commande `injectall`.

Il contient plusieurs sections :

- `position` : les coordonnées de la mission, utilisées pour calculer l'heure du coucher et du lever du soleil.

- `moments` : un tableau de moments, chaque moment définissant une heure et une date spécifiques qui peuvent être utilisées dans la section `targets`. 
Ils sont définis avec des expressions Javascript et des valeurs temporelles ; vous pouvez utiliser les variables *sunset* et *sunrise* (par exemple, 3h après le coucher du soleil : `sunset + 3*60`, ou 21h15 : `21:15`). 
Par défaut, ces moments sont déjà définis :

  - nuit : 02:00
  - avant l'aube : 01h30 à l'aube
  - lever du soleil : lever du soleil
  - aube : 0h30 après le lever du soleil
  - matin : 1h30 après le lever du soleil
  - jour : 15:00
  - avant le coucher du soleil : 1h30 au coucher du soleil
  - coucher de soleil : coucher de soleil

- `targets` : un tableau de cibles, chaque cible contenant les conditions météorologiques et de départ qui seront utilisées pour créer une version spécifique du fichier de mission.

Chaque cible peut contenir les options listées [ici](#common-options), et doit définir le nom de la version qui sera générée avec `version` (utilisé pour créer le nom du fichier de la mission ; par exemple `my-mission-beforedawn-real-clear.miz` à partir de `my-mission.miz`).

Exemple d'un fichier de versions :

```json
{
  "variableForMetar" : "METAR",
  "moments" : 
    {
      "onehour_tosunrise" : "sunrise-60*60",
      "tard_matin" : "lever du soleil+120*60"
    },
  "position" : 
    {
      "lat" : 42.355691,
      "lon" : 43.323853,
      "tz" : "Asie/Tbilissi"
    },
  "cibles" : [
    {
      "version" : "beforedawn-real-clear",
      "realweather" : vrai,
      "clearsky" : vrai,
      "moment" : "avant l'aube"
    },
    {
      "version" : "beforesunrise-real",
      "realweather" : vrai,
      "moment" : "onehour_tosunrise"
    },
    {
      "version" : "dawn-broken",
      "weatherfile" : "broken-1.lua",
      "moment" : "aube"
    },
    {
      "version" : "dawn-crosswind-vaziani",
      "weather" : "UG27 221130Z 04515KT CAVOK Q1020 NOSIG",
      "moment" : "aube"
    }
  ]
}
```

### Fichier de configuration

Le fichier de configuration est situé dans le répertoire de travail de l'outil, et est nommé `configuration.json`.

Il sera créé automatiquement la première fois que vous exécuterez l'outil, et contient les sections suivantes :

- `theatres` : une liste de théâtres, avec les coordonnées où la météo sera recherchée avec CheckWX.

- `cacheFolder` : le dossier où les fichiers de cache de la météo seront stockés.

- `maxAgeInHours` : l'âge maximum des fichiers de cache météo, en heures.

- `checkwx_apikey` : la clé API à utiliser pour récupérer la météo depuis CheckWX. Obtenez-en une [ici] (https://www.checkwxapi.com/).

Exemple d'un fichier de configuration :

```json
{
  "théâtres" : {
    "caucase" : {
      "lat" : 42.355691,
      "lon" : 43.323853
    },
    "persiangulf" : {
      "lat" : 26.304151,
      "lon" : 56.378506
    },
    "nevada" : {
      "lat" : 36.145615,
      "lon" : -115.187618
    },
    "normandy" : {
      "lat" : 49.183336,
      "lon" : -0.365908
    },
    "syria" : {
      "lat" : 32.666667,
      "lon" : 35.183333
    },
    "marianaislands" : {
      "lat" : 14.079866,
      "lon" : 145.15311411102653
    }
  },
  "checkwx_apikey" : "53506465454660465040465",
  "cacheFolder" : "./cache",
  "maxAgeInHours" : 1
}
```

### Injection de la météo du monde réel

C'est la valeur par défaut s'il n'y a pas de fichier météo METAR ou DCS spécifié dans les options.

La météo sera récupérée à partir de l'aéroport le plus proche des coordonnées du théâtre de la mission définies dans le fichier [`configuration.json`](#configuration-file).

L'outil utilise l'API CheckWX pour récupérer la météo ; vous devez vous inscrire auprès de CheckWX et obtenir une clé API gratuite (voir [ici](https://www.checkwxapi.com/)), puis la stocker dans le fichier [`configuration.json`](#configuration-file).

La météo récupérée sera stockée dans un fichier cache, afin que l'outil n'ait pas à récupérer la météo à chaque fois qu'il s'exécute. Ceci afin d'éviter de surcharger l'API CheckWX.

L'emplacement du cache, ainsi que le délai d'expiration du cache, peuvent être configurés dans le fichier [`configuration.json`](#configuration-file).

Exemple d'utilisation de `inject` pour injecter la météo du monde réel :

``cmd
veaf-tools inject my-mission.miz my-mission-real.miz --real
```

Exemple d'utilisation de `injectall` pour injecter la météo du monde réel :

```json
{
  "variableForMetar" : "METAR",
  "position" : 
    {
      "lat" : 42.355691,
      "lon" : 43.323853,
      "tz" : "Asie/Tbilissi"
    },
  "cibles" : [
    {
      "version" : "beforedawn-real-clear",
      "realweather" : vrai,
      "clearsky" : vrai,
      "moment" : "avant l'aube"
    },
    {
      "version" : "dawn-real",
      "realweather" : vrai,
      "moment" : "aube"
    }
  ]
}
```

``cmd
veaf-tools injectall ma-mission.miz ma-mission-${version}.miz versions.json
```

### Injection d'un temps prédéfini

En utilisant un METAR ou un fichier météo DCS, vous pouvez injecter une météo prédéfinie dans le fichier de mission.

Vous pouvez extraire la définition de la météo d'une mission DCS en éditant le fichier `mission` qui est stocké dans le fichier ".miz" (indice : c'est une archive ZIP), et en cherchant la section `["weather"]`. Ecrivez cette section dans un fichier LUA, et utilisez-la comme paramètre `--weather` ou comme option `weatherFile`.

Voici un exemple de définition d'un temps DCS :

``lua``
["météo"] = {
  ["atmosphere_type"] = 0,
    ["nuages"] = 
    {
        ["épaisseur"] = 200,
        ["densité"] = 0,
        ["preset"] = "Preset13",
        ["base"] = 3400,
        ["iprecptns"] = 0,
    }, -- fin de ["nuages"].
    ["cyclones"] = {
  }, -- fin de [ "cyclones" ].
  ["dust_density"] = 0,
  ["enable_dust"] = false,
  ["enable_fog"] = false,
  ["brouillard"] = {
      ["épaisseur"] = 0,
      ["visibilité"] = 0,
  }, -- fin de ["brouillard"].
  ["groundTurbulence"] = 26.656422237728,
  ["qnh"] = 758.444,
  ["saison"] = {
      ["température"] = 23.200000762939,
  }, -- fin de la ["saison"].
  ["type_météo"] = 2,
  ["visibilité"] = {
      ["distance"] = 1593,
  }, -- fin de ["visibilité"].
  ["wind"] = {
      ["at2000"] = {
          ["dir"] = 148,
          ["vitesse"] = 10.604474819794,
      }, -- fin de ["at2000"]
      ["at8000"] = {
          ["dir"] = 160,
          ["vitesse"] = 12.07985101455,
      }, -- fin de ["at8000"]
      ["atGround"] = {
          ["dir"] = 150,
          ["vitesse"] = 4,5,
      }, -- Fin de ["atGround"].
  }, -- fin de ["vent"].
}, -- fin de ["météo"].
```

``cmd
veaf-tools inject my-mission.miz my-mission-real.miz --weather scattered-rain.lua
```

Ou, si vous utilisez `injectall` :

```json
{
  "variableForMetar" : "METAR",
  "position" : 
    {
      "lat" : 42.355691,
      "lon" : 43.323853,
      "tz" : "Asie/Tbilissi"
    },
  "cibles" : [
    {
      "version" : "dawn-broken",
      "weatherfile" : "broken-1.lua",
      "moment" : "aube"
    }
  ]
}
```

``cmd
veaf-tools injectall ma-mission.miz ma-mission-${version}.miz versions.json
```

L'utilisation d'un METAR est plus facile, car vous pouvez l'obtenir sur l'internet. Voici un exemple :

``cmd
veaf-tools injecter my-mission.miz my-mission-real.miz --metar "UG27 221130Z 04515KT CAVOK Q1020 NOSIG"
```

Ou, si vous utilisez `injectall` :

```json
{
  "variableForMetar" : "METAR",
  "position" : 
    {
      "lat" : 42.355691,
      "lon" : 43.323853,
      "tz" : "Asie/Tbilissi"
    },
  "cibles" : [
    {
      "version" : "dawn-crosswind-vaziani",
      "weather" : "UG27 221130Z 04515KT CAVOK Q1020 NOSIG",
      "moment" : "aube"
    }
  ]
}
```

``cmd
veaf-tools injectall ma-mission.miz ma-mission-${version}.miz versions.json
```

## Utilisation du sélecteur de mission

## Contacts

Si vous avez besoin d'aide ou si vous voulez suggérer quelque chose, vous pouvez le faire :

* contacter [Zip] [Zip sur Github] sur Github
* Allez sur le [site de la VEAF].
* post sur le [forum VEAF]
* Rejoignez le [Discord VEAF].

[Badge-Discord] : https://img.shields.io/discord/471061487662792715?label=VEAF%20Discord&style=for-the-badge
[VEAF-logo] : ../.images/logo.png?raw=true
[VEAF Discord] : https://www.veaf.org/discord
[Zip sur Github] : https://github.com/davidp57
[Site Internet de la VEAF] : https://www.veaf.org
[Forum VEAF] : https://www.veaf.org/forum

[install-chocolatey-nodejs-veaftools] : ../.images/install-chocolatey-nodejs-veaftools.mp4?raw=true
[veaftools-options] : ../.images/veaftools-options.png?raw=true
[veaftools-inject-options] : ../.images/veaftools-inject-options.png?raw=true
[veaftools-injectall-options] : ../.images/veaftools-injectall-options.png?raw=true
[veaftools-injectall-demo] : ../.images/veaftools-injectall-demo.mp4?raw=true
