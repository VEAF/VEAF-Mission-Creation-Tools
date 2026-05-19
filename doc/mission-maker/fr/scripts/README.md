# Référence des scripts — Modules Lua VEAF

Tous les modules sont regroupés dans `veaf-scripts.lua` et chargés au démarrage de la mission. Cette page liste chaque module avec son objectif, si une configuration explicite est nécessaire, et des liens vers le guide détaillé.

---

## Modèle de chargement et d'initialisation

Chaque module suit le même modèle :

```lua
-- Optionnel : surcharger les valeurs par défaut avant l'initialisation
veafModuleName.SomeConstant = value

-- Requis : initialiser le module
veafModuleName.initialize()

-- Certains modules nécessitent aussi un appel à start()
veafModuleName.start()
```

Les modules qui ne sont pas initialisés (`initialize()`) ne consomment aucune ressource et ne créent aucun menu radio.

---

## Modules de base

Ces modules doivent toujours être chargés. Ils fournissent l'infrastructure utilisée par tous les autres modules.

| Module | Version | Rôle | Config. requise |
|--------|---------|------|----------------|
| `veaf.lua` | 1.56+ | Framework de base — journalisation, utilitaires, wrappers mist | Non |
| `veafEventHandler.lua` | — | Écouteur et dispatcher d'événements DCS | Non |
| `veafMarkers.lua` | — | Intercepte le texte des marqueurs F10 et dispatche les commandes | Minimale |
| `veafInterpreter.lua` | — | Analyse le texte des commandes de marqueur en options structurées | Non |
| `veafRadio.lua` | — | Construit et rafraîchit le menu radio F10 dynamique | Minimale |
| `veafCacheManager.lua` | — | Met en cache les calculs coûteux | Non |

Initialisation minimale :

```lua
veafMarkers.initialize()
veafRadio.initialize()
veafRadio.refreshRadioMenu()
```

---

## Spawn et déplacement

| Module | Fichier | Rôle |
|--------|---------|------|
| [veafSpawn](veafSpawn.md) | `veafSpawn.lua` | Faire apparaître des aéronefs, unités terrestres, fumée, JTAC, cargo, convois, FARP via marqueurs |
| [veafMove](veafMove.md) | `veafMove.lua` | Déplacer ou téléporter des groupes existants ; gérer les routes de ravitailleurs |
| `veafUnits.lua` | — | Définitions de modèles d'unités (groupes, compositions, support d'ère) |
| `veafGroundAI.lua` | — | Comportement IA amélioré pour les unités terrestres |

---

## Types de mission

| Module | Fichier | Rôle |
|--------|---------|------|
| [veafCasMission](veafCasMission.md) | `veafCasMission.lua` | Zones d'entraînement CAS générées avec packages de menaces configurables |
| [veafCombatZone](veafCombatZone.md) | `veafCombatZone.lua` | Zones de combat activables/désactivables avec suivi d'objectifs |
| [veafTransportMission](veafTransportMission.md) | `veafTransportMission.lua` | Missions hélicoptère de pickup et livraison |
| [veafQraManager](veafQraManager.md) | `veafQraManager.lua` | QRA (Quick Reaction Alert) — intercepteurs IA déclenchés par des intrus |
| [veafAirWaves](veafAirWaves.md) | `veafAirWaves.lua` | Vagues récurrentes d'attaquants IA avec suivi d'état |
| `veafCombatMission.lua` | — | Classe de base pour les types de mission (pas d'utilisation directe) |

---

## Ressources et infrastructure

| Module | Fichier | Rôle |
|--------|---------|------|
| [veafAssets](veafAssets.md) | `veafAssets.lua` | Ravitailleurs, AWACS, porte-avions — suivi d'état et menus radio |
| [veafCarrierOperations](veafCarrierOperations.md) | `veafCarrierOperations.lua` | Gestion des récupérations sur porte-avions (BRC, TACAN, ICLS, alignement vent) |
| [veafGrass](veafGrass.md) | `veafGrass.lua` | Configuration de pistes en herbe non préparées |
| [veafWeather](veafWeather.md) | `veafWeather.lua` | Météo dynamique et conditions ATC |
| [veafAirbases](veafAirbases.md) | `veafAirbases.lua` | Données de bases aériennes et services ATC |
| [veafNamedPoints](veafNamedPoints.md) | `veafNamedPoints.lua` | Positions nommées sur la carte avec ATC/TACAN optionnel |

---

## Contrôle d'accès

| Module | Fichier | Rôle |
|--------|---------|------|
| [veafSecurity](veafSecurity.md) | `veafSecurity.lua` | Système de permissions basé sur les rôles (mots de passe, niveaux) |

---

## Modules de protection

| Module | Fichier | Rôle |
|--------|---------|------|
| [veafSanctuary](veafSanctuary.md) | `veafSanctuary.lua` | Zones protégées qui détruisent automatiquement les unités intruses |
| [veafMissileGuardian](veafMissileGuardian.md) | `veafMissileGuardian.lua` | Intercepte des missiles entrants spécifiques pour protéger des ressources |

---

## Intégrations tierces

| Module | Fichier | Rôle |
|--------|---------|------|
| [veafSkynetIadsHelper](veafSkynetIadsHelper.md) | `veafSkynetIadsHelper.lua` | Configure Skynet IADS depuis les données de groupes VEAF |
| `veafSkynetIadsMonitor.lua` | — | Surveille la santé de Skynet IADS et envoie des alertes radio |
| [veafHoundElintHelper](veafHoundElintHelper.md) | `veafHoundElintHelper.lua` | Enregistre les unités spawned par VEAF dans Hound ELINT |
| `veafRemote.lua` | — | Intégration des commandes distantes NIOD / SLMOD |

---

## Modules de données

Ce sont des fichiers de données pures — aucune initialisation nécessaire.

| Module | Contenu |
|--------|---------|
| `dcsUnits.lua` | Base de données de tous les types d'unités DCS avec leurs attributs |
