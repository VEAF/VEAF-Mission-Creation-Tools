# veafAirWaves — Attaques aériennes par vagues

**Module ID:** `AIRWAVES` | **Version:** 1.7.x | **Fichier:** `veafAirWaves.lua`

---

## Objectif

Définit des zones qui font apparaître des vagues récurrentes d'aéronefs IA. Quand le nombre requis de joueurs humains entre dans la zone, la première vague est lancée. À chaque vague détruite, la suivante apparaît (avec des délais optionnels). Supporte la mise à l'échelle selon le nombre de joueurs, la réinitialisation à la mort d'un joueur et des messages radio personnalisés.

---

## Dépendances

- `veafSpawn` — spawn d'aéronefs IA
- `veafRadio` — messages de statut (optionnel)

---

## Activation

Pas d'`initialize()` global. Chaque zone est créée individuellement :

```lua
local defenseZone = AirWaveZone:new()
  :setName("AW-East")
  :setZoneName("ZONE-AIRWAVES-EAST")
  :setDescription("Zone d'interception est")
  :addWave({ "MiG-23 Wave 1a", "MiG-23 Wave 1b" })
  :addWave({ "MiG-29 Wave 2" })
  :setMinimumPlayersForWave(1)
  :initialize()
```

---

## Méthodes du builder AirWaveZone

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne |
| `:setZoneName(zoneName)` | Zone de trigger DCS définissant la zone d'interception |
| `:setDescription(text)` | Libellé pour les messages et les logs |
| `:addWave(groupNames)` | Ajouter une vague (table de noms de groupes DCS) |
| `:setMinimumPlayersForWave(n)` | Nombre minimum de joueurs humains pour déclencher une vague |
| `:setPlayerCoalitions(sides)` | Quelles coalitions comptent comme joueurs |
| `:setPlayerUnitsNames(names)` | Noms spécifiques d'unités joueur à suivre |
| `:setRespawnRadius(m)` | Rayon de dispersion des spawns (défaut : 250 m) |
| `:setRespawnDefaultOffset(lat, lon)` | Décalage par rapport au centre de zone pour les spawns |
| `:setSilent(bool)` | Supprimer tous les messages |
| `:setDrawZone(bool)` | Dessiner le contour de la zone sur la carte |
| `:setOnStart(fn)` | Callback quand la zone s'active |
| `:setOnWaveDestroyed(fn)` | Callback quand une vague est détruite |
| `:setOnCompleted(fn)` | Callback quand toutes les vagues sont terminées |
| `:setMessageStart(text)` | Message personnalisé de démarrage de zone |
| `:setMessageWaitToDeploy(text)` | Message personnalisé d'arrivée de vague |
| `:setMessageWaveDeployed(text)` | Message personnalisé de vague lancée |
| `:setMessageWaveDestroyed(text)` | Message personnalisé de vague détruite |
| `:setMessageCompleted(text)` | Message personnalisé de toutes vagues terminées |

---

## Vagues

Chaque vague est une liste de noms de groupes DCS. Tous les groupes d'une vague apparaissent simultanément. La vague suivante se déclenche quand tous les groupes de la vague courante sont détruits.

```lua
:addWave({ "BanditsA", "BanditsB" })   -- vague 1 : deux groupes apparaissent en même temps
:addWave({ "BanditsC" })               -- vague 2 : un groupe
:addWave({ "BanditsD", "BanditsE", "BanditsF" })  -- vague 3
```

---

## Exemple

```lua
-- Zone nécessitant 2 joueurs humains avec 3 vagues
AirWaveZone:new()
  :setName("Intercept-West")
  :setZoneName("ZONE-WEST-INTERCEPT")
  :setDescription("Axe de menace ouest")
  :addWave({ "Su-25T Strike 1a", "Su-25T Strike 1b" })
  :addWave({ "Su-25T Strike 2a", "Su-25T Strike 2b", "Su-25T Strike 2c" })
  :addWave({ "Su-24M Deep Strike" })
  :setMinimumPlayersForWave(2)
  :setDrawZone(true)
  :setOnCompleted(function()
    trigger.action.setUserFlag("WEST_CLEAR", true)
  end)
  :initialize()
```

---

## Voir aussi

- [veafQraManager](veafQraManager.md) — système de scramble défensif
- [veafCombatZone](veafCombatZone.md) — zones de combat terrestres
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafAirWaves`
