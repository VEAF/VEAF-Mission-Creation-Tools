# Trucs en cours de réalisation / réflexion

## Fonctionnalités offertes par les outils VEAF

Ces fonctionnalités nécessitent les scripts/outils VEAF ; voir installation de l'environnement, explication générale des scripts

### Outils externes

- veafMissionFlightPlanEditor : injecte et met à jour des waypoints dans les vols d'une mission en se basant sur un fichier de configuration ; utile pour fixer les mêmes points à de nombreux vols, très pratique quand on en ajoute de nouveaux
- veafMissionNormalizer : nettoie et trie les éléments d'un fichier de mission lua toujours de la même manière ; utilisé pour comparer facilement les versions
- veafMissionRadioPresetsEditor : injecte et met à jour les presets radio des vols dans une mission en se basant sur un fichier de configuration ; utilisé pour le plan de fréquence VEAF
- veafMissionTriggerInjector : injecte dans une mission "non VEAF" les triggers de chargement et de configuration des scripts ; utilisé par le Mission Converter
- veafSpawnableAircraftsEditor : injecte et met à jour des vols dans une mission en se basant sur un fichier de configuration ; utilisé pour ajouter les CAP dans les missions, par exemple

### Fonctionnalités de gestion des serveurs

- VEAF-Server-hook : permet de gérer des trucs dans la mission (envoi de commandes, gestion des permissions) et de gérer le restart du serveur
- veafRemote : interface de pilotage de la mission par des commandes externes (chat, socket TCP)

### Support de fonctionnalités apportées par des scripts communautaires

- Hound Elint : reconnaissance électronique (pas sûr que ça marche)
- CTLD : emport et dépose de troupes et logistique par hélico et avion de transport
- Skynet IADS : gestion en réseau des défenses aériennes

### Fonctionnalités dynamiques au démarrage 

Initialisation au build, utilisation au runtime

- veafGrass : gestion des FARP et des pistes en herbe
- veafCombatMission : missions dans la mission, combat air-air
- veafCombatZone : missions dans la mission, combat air-sol
- veafQra : zone ennemie protégée par une patrouille de combat
- veafInterpreter : tout un programme ! gestion de spawn dynamique au lancement de la mission ou d'une combat zone, par le nom des unités qui contiennent des commandes
- veafRadio : gestion des menus radio
- veafSanctuary : définition d'une zone sûre dans laquelle le PvP est interdit et puni (un bon coup de flak dans la tronche)
- veafSecurity : gestion des permissions pour les différentes commandes

### Fonctionnalités dynamiques au runtime 

Utilisation au runtime (configuration possible au build)

- veafAssets : gestion des tankers et autres AWACS et porte-avions
- veafDrawingOnMap : gestion de petits dessins sur la carte (flèches, lignes, tout ça)
- veafCarrierOperations : opérations aéronavales (mise au vent, ATC, tanker de secours, hélico de SAR)
- veafMissileGuardian : système d'entrainement qui détruit les missiles avant qu'ils ne te détruisent (en cours de réalisation)
- veafMove : gère le déplacement de groupes (tanker, par exemple) par des markers (_move) ou le menu radio (move tanker to me)
- veafNamedPoints : placement de points nommés sur la carte (_point), ATC et météo sur ces points
- veafShortcuts : tout un programme, définition de raccourcis (alias) qui commencent par "-" et permettent de facilement déclencher des commandes plus complexes ; aléatoire, répétition, départ différé
- veafSpawn : tout un programme également, permet de faire apparaître des unités et des groupes en temps réel (commande "_spawn", support de tous les autres modules comme veafCasMission et veafShortcuts)
- veafCasMission : gestion de groupes de combat réalistes (transport, blindés, défense aérienne) dont la force est configurable (support des autres commandes comme "-transport", "-armor", "-sam" et "-convoy") ; aussi, spawn de ces groupes et gestion d'un exercice d'entrainement BAI (commande "_cas")
- veafTransportMission : création d'une mission de transport sous élingue, avec une route à faire défendue par des ennemis pour aller ravitailler des alliés
- veafUnits : support des scripts de spawn (définition des groupes prédéfinis)
- dcsUnits : support des scripts de spawn (base de données des unités de DCS)

## Fonctionnalités offertes en plus des outils VEAF

Ces fonctionnalités ne nécessitent pas les scripts/outils VEAF.

### Outils externes

- dictionaryNormalizer : même principe que pour mission normalizer, utile pour comparer deux versions d'un fichier lua quelconque (options.lua sur le serveur par exemple)
- DCS fiddle : debugging en temps réel de missions DCS (en cours d'adaptation)
- dcsDataExport : export de la base de données des unités de DCS

### Fonctionnalités de gestion des serveurs

- tout le bazar pour gérer la surveillance des serveurs ; voir la doc du repo serveur

### Fonctionnalités dynamiques au démarrage 


### Fonctionnalités dynamiques au runtime 

- trainingSpawnZone ; script pour Sharko qui gère des zones d'entrainement où on spawn des IA
- blueJaagAirWaves ; script pour BlueJaag qui gère des zones de combat avec spawn de vagues d'IA (en cours de réalisation)