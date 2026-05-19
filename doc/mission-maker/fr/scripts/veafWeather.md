# veafWeather — Météo dynamique et conditions ATC

**Module ID:** `WEATHER` | **Version:** — | **Fichier:** `veafWeather.lua`

---

## Objectif

Fournit des rapports météo et l'injection de météo dynamique pour les missions DCS. Génère des rapports lisibles au format METAR et s'intègre avec `veaf-tools.exe weather-inject` pour injecter de la météo réelle ou configurée au moment du build.

---

## Dépendances

- `veafRadio` — menu météo optionnel
- `veafNamedPoints` — pour les rapports météo basés sur la localisation

---

## Activation

```lua
veafWeather.initialize()
```

---

## Injection de météo au moment du build

La météo est injectée au moment du build (avant le chargement de la mission) avec `veaf-tools.exe` :

```powershell
veaf-tools.exe weather-inject --mission mission.miz --config weather.yaml
```

### Exemple weather.yaml

```yaml
weather:
  source: metar          # "metar" (temps réel) ou "manual"
  icao: UGSS             # Code ICAO de l'aéroport pour le METAR (Senaki)
  # override manuel (utilisé quand source: manual)
  wind:
    speed: 10            # nœuds
    direction: 270       # degrés
  visibility: 8000       # mètres
  clouds:
    base: 2500           # pieds
    density: 5           # 0-10
  temperature: 18        # °C
  qnh: 1013              # hPa
```

---

## Rapport météo au runtime

Obtenir un rapport météo pour une position :

```lua
local report = veaf.weatherReport(position, altitude, withLASTE)
veaf.outTextForUnit(unitName, report, 30)
```

---

## Menu radio F10

Si activé, fournit un sous-menu **Météo** où les joueurs peuvent demander des rapports météo locaux.

---

## Voir aussi

- [Référence des outils](../../../TOOLS_REFERENCE.md) — référence complète de `veaf-tools.exe weather-inject`
- [Référence API Lua](../../../LUA_API_REFERENCE.md) — API complète de `veafWeather`
