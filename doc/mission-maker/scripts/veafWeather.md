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

Le sous-menu **WEATHER AND ATC** du menu radio F10 permet aux joueurs d'obtenir des informations détaillées sur la météo et la base aérienne la plus proche.

- **Weather on closest point** — météo locale adaptée au type d'appareil (unités et format conformes à l'avion du joueur)
- **ATC on closest airbase** — informations ATIS de la base la plus proche (piste en service, QFU, etc.)
- **ATC and weather in one go** — les deux d'un coup

Ces commandes sont aussi accessibles depuis le chat multijoueur (avec le hook serveur VEAF) : `atc`

---

## Gestion du brouillard

Le brouillard peut être contrôlé en cours de mission — utile pour l'immersion, les scénarios d'entraînement ou les événements scriptés.

> ⚠️ **Dépendant de la carte/version DCS** : le contrôle du brouillard utilise l'API moderne de DCS (`world.weather.setFogThickness` / `setFogAnimation`). Il est vérifié fonctionnel sur le **Caucase**. Si le brouillard ne change pas en jeu sur une carte donnée, c'est une **limitation de DCS** (support du brouillard variable selon la carte/version), pas un bug de VEAF.

### Constantes prédéfinies

Trois familles de brouillard sont disponibles. S'active avec `:activate()` :

**Brouillard dynamique** — recalcule la densité périodiquement selon les conditions météo :

```lua
veafWeather.FOG_DYNAMIC_HEAVY:activate()
veafWeather.FOG_DYNAMIC_MEDIUM:activate()
veafWeather.FOG_DYNAMIC_SPARSE:activate()
```

**Brouillard statique** — visibilité fixe :

```lua
veafWeather.FOG_STATIC_HEAVY:activate()
veafWeather.FOG_STATIC_MEDIUM:activate()
veafWeather.FOG_STATIC_MEDIUM_LOW:activate()
veafWeather.FOG_STATIC_SPARSE:activate()
veafWeather.FOG_STATIC_SPARSE_LOW:activate()
veafWeather.FOG_STATIC_NO:activate()    -- supprime tout brouillard
```

**Brouillard animé** — transition progressive vers un état cible. Syntaxe : `FOG_ANIMATED_<DURÉE>M_<DENSITÉ>` :

| Durée | Variantes de densité |
|-------|---------------------|
| `1M`, `5M`, `10M`, `15M`, `30M`, `60M`, `90M` | `HEAVY`, `MEDIUM`, `MEDIUM_LOW`, `SPARSE`, `SPARSE_LOW`, `NO` |

Exemples :

```lua
veafWeather.FOG_ANIMATED_10M_MEDIUM:activate()   -- brouillard moyen en 10 minutes
veafWeather.FOG_ANIMATED_30M_NO:activate()       -- dissipation en 30 minutes
veafWeather.FOG_ANIMATED_5M_HEAVY:activate()     -- brouillard épais en 5 minutes
```

### Activer un objet brouillard directement

```lua
veafWeather.setAndActivateFog(veafWeather.FOG_STATIC_MEDIUM)
```

C'est équivalent à appeler `:activate()` sur la constante. Tout brouillard actif précédemment est d'abord annulé.

### Déclencher un changement de brouillard depuis un trigger

```lua
-- Sur un trigger DCS « Début phase de nuit », activer un brouillard épais
mist.scheduleFunction(function()
    veafWeather.FOG_ANIMATED_15M_HEAVY:activate()
end, {}, timer.getTime() + 0)
```

---

## Commandes chat / à distance

| Commande | Effet |
|----------|-------|
| `_weather` | Rapport météo à la position courante |
| `_atc` | ATIS de la base aérienne la plus proche |
| `_weather fog FOG_STATIC_MEDIUM` | Activer une constante de brouillard |
| `_weather fog FOG_ANIMATED_10M_NO` | Dissipation animée en 10 minutes |

Le nom de la constante est insensible à la casse (sans le préfixe `veafWeather.`).

---

## Voir aussi

- [Référence des outils](../../TOOLS_REFERENCE.md) — référence complète de `veaf-tools.exe weather-inject`
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafWeather`
