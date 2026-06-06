# veafGrass — Configuration de pistes en herbe

**Module ID:** — | **Fichier:** `veafGrass.lua`

---

## Objectif

Configure des pistes en herbe non préparées pour une utilisation dans les missions DCS. Fournit des données de positionnement, des fréquences radio et des aides à l'atterrissage pour les zones d'atterrissage en campagne qui ne sont pas des bases aériennes DCS standard.

---

## Activation

```lua
veafGrass.initialize()
```

Puis définir chaque piste :

```lua
VeafGrassRunway:new()
  :setName("FARP Whiskey")
  :setGroupName("FARP-WHISKEY-GROUP")   -- objets statiques définissant la piste
  :setRunwayHeading(270)                -- cap de piste en degrés
  :setAtcFrequency(127500000)           -- Hz (127,5 MHz)
  :setAtcModulation(radio.modulation.AM)
  :setTacanChannel(74, "X", "WHK")     -- TACAN optionnel
  :initialize()
```

---

## Méthodes du builder

| Méthode | Description |
|---------|-------------|
| `:setName(name)` | Identifiant interne et libellé |
| `:setGroupName(name)` | Groupe DCS d'objets statiques formant la piste |
| `:setRunwayHeading(deg)` | Cap magnétique principal de la piste |
| `:setAtcFrequency(hz)` | Fréquence radio ATC en Hz |
| `:setAtcModulation(mod)` | `radio.modulation.AM` ou `FM` |
| `:setTacanChannel(ch, band, morse)` | Canal TACAN, bande (X/Y), identifiant Morse |
| `:initialize()` | Enregistrer la piste |

---

## Notes

- Le "groupe" doit contenir les objets statiques (manche à air, camions-citerne, etc.) qui définissent visuellement la piste
- La position et le cap sont lus depuis l'unité de tête du groupe
- La fréquence ATC est annoncée via le menu F10 et dans les messages radio

---

## Voir aussi

- [veafAssets](veafAssets.md) — pour les ravitailleurs et AWACS gérés aux bases régulières
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafGrass`
