# veafSkynetIadsHelper — Intégration Skynet IADS

**Module ID:** — | **Fichier:** `veafSkynetIadsHelper.lua`

---

## Objectif

Intègre les groupes de missions VEAF avec le script tiers [Skynet IADS](https://github.com/walder/Skynet-IADS). Enregistre automatiquement les sites SAM, les radars de veille électronique (EWR) et les centres de commandement définis dans les missions VEAF dans le réseau Skynet, permettant un comportement IADS coordonné.

---

## Prérequis

- Le script Skynet IADS doit être chargé avant `veafSkynetIadsHelper`
- Skynet doit être initialisé dans votre mission

---

## Activation

```lua
-- Charger Skynet en premier (dans vos triggers DO SCRIPT FILE ou mission-script.lua)
-- Puis :
veafSkynetIadsHelper.initialize()
```

---

## Enregistrement

Les groupes VEAF peuvent être enregistrés dans Skynet via des conventions de nommage ou des appels explicites :

```lua
-- Enregistrer un site SAM par nom de groupe DCS
veafSkynetIadsHelper.addSamSiteByGroupName("SA-6 Battery Alpha", iads)

-- Enregistrer un EWR par nom de groupe
veafSkynetIadsHelper.addEwrByGroupName("EWR P-18 North", iads)

-- Enregistrer tous les groupes correspondant à un préfixe
veafSkynetIadsHelper.addAllGroupsMatchingPrefix("SAM-", iads)
```

---

## Enregistrement automatique lors du spawn

Quand `veafSpawn` crée de nouvelles unités SAM ou EWR, `veafSkynetIadsHelper` peut les enregistrer automatiquement :

```lua
-- Activer l'enregistrement automatique pour les unités spawned dynamiquement
veafSkynetIadsHelper.autoRegisterSpawnedUnits = true
```

---

## Notes

- Skynet IADS est un script tiers non inclus dans VEAF — à télécharger séparément
- Les noms de groupes dans l'éditeur DCS doivent correspondre à ceux que vous enregistrez
- Consulter la [documentation Skynet IADS](https://github.com/walder/Skynet-IADS) pour les options de configuration IADS

---

## Voir aussi

- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafSkynetIadsHelper`
