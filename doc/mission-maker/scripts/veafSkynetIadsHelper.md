# veafSkynetIadsHelper — Intégration Skynet IADS

**Module ID :** `SKYNET` | **Fichier :** `veafSkynetIadsHelper.lua` | **Table Lua :** `veafSkynet`

---

## Objectif

[Skynet-IADS](https://github.com/walder/Skynet-IADS) est un script tiers qui pilote les systèmes radar antiaériens afin qu'ils optimisent leur survivabilité et leur léthalité en restant éteints le plus possible. Il simule un IADS (Integrated Air Defence System) dans lequel les EWR (Early Warning Radar) scannent le ciel et communiquent leurs détections aux sites SAM, permettant à ceux-ci de ne s'activer que lorsqu'ils sont en capacité d'engager un contact.

`veafSkynetIadsHelper` automatise la construction de ces réseaux à partir des groupes présents dans la mission, et fournit des outils pour les surveiller, les contrôler et les lier à des objectifs de mission.

---

## Prérequis

- Le script Skynet IADS doit être téléchargé séparément et chargé **avant** `veafSkynetIadsHelper`
- Configurer via `mission.yaml` (recommandé) ou directement dans `missionConfig.lua`

---

## Configuration (`mission.yaml`)

```yaml
external_modules:
  skynet:
    enabled: true
    include_red_in_radio: false   # afficher l'état du réseau rouge dans le menu F10
    debug_red: false              # logs détaillés Skynet pour le réseau rouge
    include_blue_in_radio: false  # afficher l'état du réseau bleu dans le menu F10
    debug_blue: false             # logs détaillés Skynet pour le réseau bleu
```

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `enabled` | booléen | `false` | Activer l'intégration Skynet |
| `include_red_in_radio` | booléen | `false` | Ajouter l'état IADS rouge au menu radio F10 |
| `debug_red` | booléen | `false` | Debug verbeux Skynet pour la coalition rouge |
| `include_blue_in_radio` | booléen | `false` | Ajouter l'état IADS bleu au menu radio F10 |
| `debug_blue` | booléen | `false` | Debug verbeux Skynet pour la coalition bleue |

---

## Activation (via `missionConfig.lua`)

```lua
if veafSkynet then
    veafSkynet.PointDefenceMode = veafSkynet.PointDefenceModes.Skynet
    veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Strict
    veafSkynet.DynamicSpawn = false
    veafSkynet.DelayForStartup = 5
    veafSkynet.initialize(
        false, -- includeRedInRadio
        false, -- debugRed
        false, -- includeBlueInRadio
        false  -- debugBlue
    )
end
```

---

## Principes de fonctionnement

Le module parcourt la liste de tous les groupes de la mission au démarrage, et ajoute ceux qui sont éligibles dans les réseaux IADS Skynet. Cette initialisation se fait avec un délai paramétrable (`DelayForStartup`) pour laisser les autres modules s'initialiser en premier. Les groupes en activation retardée sont intégrés au démarrage, mais pas les groupes générés dynamiquement (sauf si `DynamicSpawn = true`).

Le module crée toujours deux réseaux Skynet : un pour la coalition **bleue**, un pour la coalition **rouge**.

---

## Propriétés globales (à définir avant `initialize`)

### Mode Point Defence — `veafSkynet.PointDefenceMode`

Identifie les sites SAM capables d'intercepter des missiles antiradar et les affecte en défense rapprochée d'autres éléments du réseau.

| Valeur | Description |
|--------|-------------|
| `veafSkynet.PointDefenceModes.None` | Pas de défenses rapprochées (**défaut**) |
| `veafSkynet.PointDefenceModes.Skynet` | Défenses rapprochées gérées par Skynet (recommandé si activé) |
| `veafSkynet.PointDefenceModes.Dcs` | Exclut les défenses rapprochées du réseau IADS — laissées à l'IA DCS (toujours allumées, plus efficaces mais vulnérables) |

### Mode d'intégration des groupes — `veafSkynet.GroupIntegrationMode`

Détermine quels groupes DCS sont intégrés dans les réseaux Skynet.

| Valeur | Description |
|--------|-------------|
| `veafSkynet.GroupIntegrationModes.Strict` | Seuls les groupes composés **uniquement** d'unités connues de Skynet sont intégrés |
| `veafSkynet.GroupIntegrationModes.Lenient` | Les groupes contenant **au moins une** unité connue de Skynet sont intégrés (**défaut**) |

Le mode `Lenient` intégrera un convoi composé de tanks, transports **et** d'une SA-19 d'escorte. Le mode `Strict` ne l'intégrera pas.

### Spawn dynamique — `veafSkynet.DynamicSpawn`

| Valeur | Description |
|--------|-------------|
| `false` | Seuls les groupes présents au démarrage sont intégrés (**défaut**) |
| `true` | Les groupes générés en cours de mission sont également intégrés dans les réseaux existants |

> `veafSpawn` ajoute automatiquement les unités SAM qu'il génère dans les réseaux Skynet, sauf si `DynamicSpawn = true` (dans ce cas `veafSkynet` gère lui-même cette surveillance).

### Délai de démarrage — `veafSkynet.DelayForStartup`

Nombre de secondes à attendre avant d'initialiser les réseaux (défaut : `1`). À augmenter si d'autres modules initialisent des groupes en retard.

---

## Centres de commandement

Dans Skynet, un **Command Center** est une unité ou un statique dont dépend le fonctionnement d'un réseau. Si tous les Command Centers d'un réseau sont détruits, ce réseau bascule en mode autonome (tous les éléments restent allumés en permanence, mais bénéficient toujours des intelligences de Skynet, notamment l'évasion HARM).

Cette mécanique permet de donner des objectifs de mission concrets : détruire le centre de commandement pour désorganiser la défense aérienne.

```lua
-- Ajouter un Command Center à un réseau (peut être un groupe, une unité ou un statique)
veafSkynet.addCommandCenterOfCoalition(coalition.side.RED, "CommandCenterRed")

-- Détruire (faire exploser) tous les Command Centers d'un réseau
veafSkynet.destroyCommandCentersOfCoalition(coalition.side.RED)
```

---

## Désactivation d'un réseau

Désactive un réseau Skynet et bascule tous ses éléments dans un état défini avant de les rendre à l'IA DCS.

```lua
veafSkynet.deactivateNetworkOfCoalition(coalition.side.RED)
-- ou avec un état spécifique :
veafSkynet.deactivateNetworkOfCoalition(coalition.side.RED, veafSkynet.SkynetElementStates.Dark)
```

| État | Description |
|------|-------------|
| `veafSkynet.SkynetElementStates.Autonomous` | Mode autonome selon la configuration de chaque élément |
| `veafSkynet.SkynetElementStates.Live` | Tous les éléments allumés (**défaut**) |
| `veafSkynet.SkynetElementStates.Dark` | Tous les éléments éteints |

---

## Accéder aux réseaux générés

Après l'initialisation (qui se fait en différé), on peut accéder aux objets réseaux Skynet via une tâche différée :

```lua
local assignRedIadsTaskId = nil
local myRedIads = nil

local function AssignRedIadsTask()
    if not veafSkynet then
        mist.removeFunction(assignRedIadsTaskId)
        return
    end
    if veafSkynet.initialized then
        mist.removeFunction(assignRedIadsTaskId)
        local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(coalition.side.RED)])
        myRedIads = veafSkynetNetwork.iads
    end
end

assignRedIadsTaskId = mist.scheduleFunction(AssignRedIadsTask, {}, timer.getTime() + veafSkynet.DelayForStartup + 1, 10)
```

---

## Exemple — Bascule en autonome contrôlée par un objectif

Cet exemple crée un Command Center depuis un template, puis expose des fonctions pour activer/désactiver le réseau selon l'évolution de la mission.

```lua
local function SkynetNetworkEnable(iCoalition)
    local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(iCoalition)])
    local iads = veafSkynetNetwork.iads
    if #iads:getCommandCenters() > 0 and iads:isCommandCenterUsable() then
        return -- déjà actif
    end
    -- Cloner un groupe template dans une zone dédiée
    local sTemplateName = "SkynetCommandCenterRed"
    local ccData = mist.cloneInZone(sTemplateName, "SkynetCommandCenterZone")
    veafSkynet.addCommandCenterOfCoalition(iads:getCoalition(), ccData.name)
end

local function SkynetNetworkDisable(iCoalition)
    veafSkynet.destroyCommandCentersOfCoalition(iCoalition)
end
```

---

## Voir aussi

- [Documentation Skynet IADS](https://github.com/walder/Skynet-IADS) — script tiers (non inclus dans VEAF)
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafSkynet`
