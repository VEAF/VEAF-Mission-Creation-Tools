# veafAirbases — Données de bases aériennes et ATC

**Module ID:** `AIRBASES` | **Fichier:** `veafAirbases.lua`

---

## Objectif

Fournit des données de bases aériennes (position, altitude, caps de piste) et configure les services ATC pour les bases DCS utilisées dans la mission. Alimente `veafNamedPoints` et le menu radio F10.

---

## Activation

```lua
veafAirbases.initialize()
```

---

## Utilisation

Les données de base aérienne (pistes et orientations) sont lues automatiquement depuis l'environnement DCS lors de `veafAirbases.initialize()`. On peut ensuite interroger une base pour connaître la piste en service selon le vent :

```lua
veafAirbases.initialize()

local airbase = veafAirbases.getAirbaseByName("Senaki-Kolkhi")
if airbase then
  -- piste en service pour une direction de vent vrai donnée (degrés)
  local runway = airbase:getRunwayInServiceString(270)
  veaf.outTextForUnit(unitName, airbase:toString(), 20)
end
```

On peut aussi récupérer la base la plus proche d'une unité avec `veafAirbases.getNearestAirbase(dcsUnit)`.

---

## Notes

- La plupart des bases DCS sont détectées automatiquement à l'initialisation
- La piste en service est calculée à partir de la direction du vent (`getRunwayInService` / `getRunwayInServiceString`)
- Récupérez une base par son nom (`getAirbaseByName`) ou la plus proche d'une unité (`getNearestAirbase`)

---

## Voir aussi

- [veafNamedPoints](veafNamedPoints.md) — utilise les données de base pour les points nommés
- [veafCarrierOperations](veafCarrierOperations.md) — ATC spécifique aux porte-avions
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafAirbases`
