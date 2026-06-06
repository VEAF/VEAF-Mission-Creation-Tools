# veafAirbases — Données de bases aériennes et ATC

**Module ID:** — | **Fichier:** `veafAirbases.lua`

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

Les données de base aérienne sont lues automatiquement depuis l'environnement DCS. Les créateurs de missions peuvent surcharger ou compléter les données :

```lua
-- Enregistrer une configuration de base aérienne personnalisée
veafAirbases.setAirbaseData("Senaki-Kolkhi", {
  atcFrequency = 127500000,   -- Hz
  atcModulation = radio.modulation.AM,
  elevation = 43,             -- mètres
  runways = {
    { heading = 110, ils = { frequency = 109300000, course = 110 } },
    { heading = 290 },
  },
})
```

---

## Notes

- La plupart des bases DCS sont déjà connues du module
- Ne surcharger que si des fréquences personnalisées ou des corrections sont nécessaires
- Les données TACAN/ILS sont utilisées par `veafNamedPoints` et les opérations de porte-avions

---

## Voir aussi

- [veafNamedPoints](veafNamedPoints.md) — utilise les données de base pour les points nommés
- [veafCarrierOperations](veafCarrierOperations.md) — ATC spécifique aux porte-avions
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafAirbases`
