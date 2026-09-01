# veafWeather — Météo dynamique et conditions ATC

**Module ID:** `WEATHER` | **Fichier:** `veafWeather.lua`

---

## Objectif

Deux rôles distincts :

1. **Au build** : injecter dans un `.miz` une météo réelle ou configurée, avant même que les joueurs chargent la mission. C'est le travail de `.\veaf-tools.exe content inject-weather`.
2. **En jeu** : les joueurs demandent des rapports météo et des informations ATC via le menu radio F10, et le créateur de mission peut scripter des changements de brouillard dynamiques.

Les rapports sont générés au format METAR, lisible par un pilote.

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
.\veaf-tools.exe content inject-weather mission.miz --config-file versions.yaml
```

### Exemple versions.yaml

```yaml
position:
  latitude: 33.5
  longitude: 35.5
  timezone: "Asia/Damascus"
base_date: "2024-03-15"
versions:
  - name: noon-clear
    time: "12:00"
    weather:
      temperature: 25.0
      wind_speed: 8.0
      wind_direction: 270.0
      visibility: 10000.0
      cloud_type: "clear"
      fog_enabled: false
  - name: with-metar
    time: "14:00"
    metar: "METAR OSDI 151420Z 27015G25KT 9999 BKN025 18/12 Q1018 NOSIG"
```

---

## Rapport météo au runtime

Obtenir un rapport météo pour une position (un `vec3`) :

```lua
local report = veafWeatherData.getWeatherString(position)
veaf.outTextForUnit(unitName, report, 30)
```

Les arguments suivants sont optionnels : `getWeatherString(vec3, dcsElementName, unitSystem, iSurfaceAltitudeMeters)`. En passant le nom d'une unité DCS comme `dcsElementName`, le rapport s'adapte au type d'appareil (système d'unités, données LASTE pour le A-10).

---

## Menu radio F10

Le sous-menu **WEATHER AND ATC** du menu radio F10 permet aux joueurs d'obtenir des informations détaillées sur la météo et la base aérienne la plus proche.

| Entrée | Accessible à | Ce qu'elle affiche |
|--------|--------------|--------------------|
| Weather on closest point | Par groupe | Vent, visibilité, QNH, température au point nommé le plus proche — unités et format adaptés à l'appareil du joueur |
| ATC on closest airbase | Par groupe | Piste en service, QFE/QNH, informations de circuit sur la base la plus proche |
| ATC and weather in one go | Par groupe | Les deux rapports d'un coup |
| Fog settings → … | Tous (sécurisé) | Modifier les conditions de brouillard (voir plus bas) |

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
veaf.scheduleFunction(function()
    veafWeather.FOG_ANIMATED_15M_HEAVY:activate()
end, {}, timer.getTime() + 0)
```

---

## Commandes chat / à distance

Ces commandes passent par le tchat (nécessite `veafRemote` et le [hook serveur](veafServerHook.md)) —
il n'existe pas de commande de marqueur pour ce module. Les trois alias `/weather`, `/atc` et `/atis`
sont interchangeables ; c'est le mot qui suit qui choisit l'action :

| Commande | Effet |
|----------|-------|
| `/atis` (ou `/weather`, `/atc`, sans argument) | Rapport ATC + météo à la position courante |
| `/weather weather` | Rapport météo seul |
| `/atc atc` | ATIS de la base aérienne la plus proche seul |
| `/weather fog FOG_STATIC_MEDIUM` | Activer une constante de brouillard |
| `/weather fog FOG_ANIMATED_10M_NO` | Dissipation animée en 10 minutes |

Le nom de la constante est insensible à la casse (sans le préfixe `veafWeather.`).

---

## Accueil à la prise de slot {#welcome-brief}

Quand un pilote prend un slot, il reçoit quelques secondes plus tard un message court : le terrain le plus
proche, la **piste en service** déduite du vent, et la météo du moment.

```
Bienvenue à Kobuleti — piste en service 13
WIND 270/10 QNH 1013 ...
```

Le message va **à son groupe seulement**, pas à la coalition : il parle de *son* terrain, et diffusé à
tout le monde il deviendrait du bruit dès que deux pilotes prennent des slots sur des bases différentes.

Quelques choix à connaître :

- **Il est différé de quelques secondes.** Un pilote qui vient d'entrer dans son appareil charge encore
  son cockpit ; un message affiché à cet instant est un message qu'il ne lit pas.
- **Il se répète à chaque prise de slot.** Un pilote qui change de terrain veut la piste du nouveau
  terrain, et « une fois par session » retiendrait justement l'information qui a changé.
- **Un porte-avions n'a pas de piste en service** — il se met au vent, donc la piste est mobile. Il
  annonce à la place son **cap actuel (vrai)**, dans les mêmes termes que l'ATC du groupe aéronaval.
  Une **hélisurface** n'a ni l'un ni l'autre : elle donne la météo seule.
- Le rapport **complet** (ATIS) reste disponible dans le menu radio. L'accueil est volontairement plus
  court : un message qui remplit l'écran à chaque changement de slot cesse d'être lu.

Pour le désactiver — par exemple si votre mission fait son propre briefing :

```yaml
modules:
  WEATHER:
    enabled: true
    welcomeBrief: false
```

---

## Voir aussi

- [Référence CLI](../../CLI_REFERENCE.md#inject-weather) — toutes les options de `veaf-tools content inject-weather`
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafWeather`
