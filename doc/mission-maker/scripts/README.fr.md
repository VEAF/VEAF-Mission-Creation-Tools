# Référence des scripts — Modules Lua VEAF

Tous les modules sont regroupés dans `veaf-scripts.lua` et chargés au démarrage de la mission. Cette page vous aide à trouver le bon module pour vos besoins.

---

## Trouver un module

### Par étape du workflow mission-maker

Que construisez-vous ? Choisissez l'étape qui correspond.

| Étape | Modules | Objectif |
|-------|---------|----------|
| **Fondation** | `veaf.lua`, `veafMarkers`, `veafRadio`, `veafInterpreter`, `veafEventHandler`, `veafCacheManager` | Infrastructure de base (toujours chargée) |
| **Mise en place** | [veafSecurity](veafSecurity.md), [veafNamedPoints](veafNamedPoints.md), [veafAirbases](veafAirbases.md) | Contrôle d'accès, positions carte, données de bases |
| **Spawning** | [veafSpawn](veafSpawn.md), [veafMove](veafMove.md) | Permettre aux joueurs de créer et déplacer des unités |
| **Types de mission** | [veafCasMission](veafCasMission.md), [veafCombatZone](veafCombatZone.md), [veafTransportMission](veafTransportMission.md), [veafQraManager](veafQraManager.md), [veafAirWaves](veafAirWaves.md) | Scénarios de gameplay structurés |
| **Assets & services** | [veafAssets](veafAssets.md), [veafCarrierOperations](veafCarrierOperations.md), [veafGrass](veafGrass.md), [veafWeather](veafWeather.md) | Ravitailleurs/AWACS/porte-avions gérés, météo |
| **Protection** | [veafMissileGuardian](veafMissileGuardian.md), [veafSanctuary](veafSanctuary.md) | Défense anti-missiles, zones sûres |
| **Intégrations** | [veafSkynetIadsHelper](veafSkynetIadsHelper.md), [veafHoundElintHelper](veafHoundElintHelper.md) | Systèmes IADS et ELINT tiers |

### Par interaction joueur

Que vivront vos joueurs ?

| Action joueur | Module | Ce qui se passe |
|---------------|--------|-----------------|
| Place un marqueur avec `_spawn ...` | [veafSpawn](veafSpawn.md) | Des unités apparaissent à la position du marqueur |
| Ouvre F10 → CAS Mission → Generate | [veafCasMission](veafCasMission.md) | Zone de cibles aléatoire générée |
| Ouvre F10 → Combat Zones → Activate | [veafCombatZone](veafCombatZone.md) | Zone de combat pré-construite activée |
| Ouvre F10 → Missions → Activate | [veafAirWaves](veafAirWaves.md) | Combat aérien par vagues lancé |
| Ouvre F10 → Assets → Tanker/AWACS | [veafAssets](veafAssets.md) | Info, respawn, recovery porte-avions |
| Ouvre F10 → Carrier → Start Recovery | [veafCarrierOperations](veafCarrierOperations.md) | Le porte-avions se met face au vent |
| Entre dans une zone protégée | [veafQraManager](veafQraManager.md) | Intercepteurs IA décollent |
| Tape `_auth [mot_de_passe]` | [veafSecurity](veafSecurity.md) | Permissions élevées accordées |
| Vole dans une zone sanctuaire | [veafSanctuary](veafSanctuary.md) | Missiles hostiles neutralisés |

### Par fréquence d'utilisation

Quelle est la fréquence d'utilisation de ce module ?

| Fréquence | Modules |
|-----------|---------|
| **Essentiel** (quasi toute mission) | [veafSpawn](veafSpawn.md), [veafAssets](veafAssets.md), [veafNamedPoints](veafNamedPoints.md), [veafSecurity](veafSecurity.md) |
| **Courant** (la plupart des missions de combat) | [veafCasMission](veafCasMission.md), [veafCombatZone](veafCombatZone.md), [veafAirWaves](veafAirWaves.md), [veafCarrierOperations](veafCarrierOperations.md) |
| **Situationnel** (scénarios spécifiques) | [veafQraManager](veafQraManager.md), [veafTransportMission](veafTransportMission.md), [veafMove](veafMove.md), [veafGrass](veafGrass.md), [veafWeather](veafWeather.md), [veafAirbases](veafAirbases.md) |
| **Spécialisé** (configurations avancées) | [veafMissileGuardian](veafMissileGuardian.md), [veafSanctuary](veafSanctuary.md), [veafSkynetIadsHelper](veafSkynetIadsHelper.md), [veafHoundElintHelper](veafHoundElintHelper.md) |

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

## Raccourcis (Aliases)

| Module | Fichier | Description |
|--------|---------|-------------|
| [veafShortcuts](veafShortcuts.md) | `veafShortcuts.lua` | Aliases courts (`-sa6`, `-shilka`, `-destroy`, etc.) pour les commandes marqueur — [voir la liste complète](veafShortcuts.md) |
| `veafTime.lua` | — | Utilitaires de temps mission |

---

## Modules de données

Ce sont des fichiers de données pures — aucune initialisation nécessaire.

| Module | Contenu |
|--------|---------|
| `dcsUnits.lua` | Base de données de tous les types d'unités DCS avec leurs attributs |
