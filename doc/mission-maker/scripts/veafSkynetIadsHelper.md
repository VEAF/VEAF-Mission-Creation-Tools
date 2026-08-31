# veafSkynetIadsHelper — Intégration Skynet IADS

**Module ID :** `SKYNET` | **Fichier :** `veafSkynetIadsHelper.lua` | **Table Lua :** `veafSkynet`

---

## Objectif

[Skynet-IADS](https://github.com/walder/Skynet-IADS) est un script tiers qui pilote les systèmes radar antiaériens afin qu'ils optimisent leur survivabilité et leur léthalité en restant éteints le plus possible. Il simule un IADS (Integrated Air Defence System) dans lequel les EWR (Early Warning Radar) scannent le ciel et communiquent leurs détections aux sites SAM, permettant à ceux-ci de ne s'activer que lorsqu'ils sont en capacité d'engager un contact.

`veafSkynetIadsHelper` automatise la construction de ces réseaux à partir des groupes présents dans la mission, et fournit des outils pour les surveiller, les contrôler et les lier à des objectifs de mission.

---

## Prérequis

- Le script Skynet IADS doit être téléchargé séparément et chargé **avant** `veafSkynetIadsHelper`
- Configurer via `mission.yaml` (recommandé) ou dans `mission-script.lua` pour les options avancées non disponibles en YAML

---

## Configuration (`mission.yaml`)

```yaml
modules:
  SKYNET:
    enabled: true
    include_red_in_radio: false   # afficher l'état du réseau rouge dans le menu F10
    debug_red: false              # logs détaillés Skynet pour le réseau rouge
    include_blue_in_radio: false  # afficher l'état du réseau bleu dans le menu F10
    debug_blue: false             # logs détaillés Skynet pour le réseau bleu
    dynamic_spawn: false          # intégrer aussi les groupes apparus en cours de mission
```

| Champ | Type | Défaut | Description |
|-------|------|--------|-------------|
| `enabled` | booléen | `false` | Activer l'intégration Skynet |
| `include_red_in_radio` | booléen | `false` | Ajouter l'état IADS rouge au menu radio F10 |
| `debug_red` | booléen | `false` | Debug verbeux Skynet pour la coalition rouge |
| `include_blue_in_radio` | booléen | `false` | Ajouter l'état IADS bleu au menu radio F10 |
| `debug_blue` | booléen | `false` | Debug verbeux Skynet pour la coalition bleue |
| `dynamic_spawn` | booléen | `false` | Intégrer aussi les groupes apparus **en cours de mission** — voir [Apparitions en cours de mission](#dynamic-spawn) |

---

## Activation (via `mission-script.lua`)

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

### Apparitions en cours de mission — `dynamic_spawn` {#dynamic-spawn}

Se règle depuis `mission.yaml` (`dynamic_spawn`), ou avant `initialize` avec `veafSkynet.DynamicSpawn`.

| Valeur | Description |
|--------|-------------|
| `false` | Seuls les groupes présents au démarrage sont intégrés (**défaut**) |
| `true` | Les groupes apparus en cours de mission rejoignent aussi les réseaux existants |

**Ce que ça coûte.** Activé, le module surveille **chaque apparition d'unité** de la mission pour repérer les groupes éligibles. C'est pour cette raison que le réglage est éteint par défaut : à activer quand la mission fait apparaître des SAM en cours de partie (zones de combat, campagne dynamique), pas systématiquement.

**Ce que ça règle.** Sans lui, un SAM apparu en cours de mission — y compris par une zone de combat — ne rejoint aucun réseau, et rien ne le dit.

**Qui décide, groupe par groupe.** L'option `skynet` d'une commande d'apparition reste maîtresse : `skynet false` garde le groupe **hors** de tout réseau (c'est ce que portent les raccourcis de convoi), et `skynet <nom de réseau>` l'envoie dans ce réseau précis plutôt que dans celui de sa coalition. Un groupe qu'aucune commande VEAF n'a déclaré — posé dans l'éditeur, créé par un script tiers — rejoint le réseau de sa coalition : c'est précisément à quoi sert ce réglage.

> Les deux chemins d'intégration sont exclusifs : quand le réseau visé intègre les apparitions, c'est lui qui fait le travail ; sinon `veafSpawn` s'en charge au moment de l'apparition. Un groupe n'est jamais intégré deux fois.

**Portée par réseau.** Le réglage est propre à chaque réseau. Éteindre l'intégration côté rouge — ou désactiver le réseau rouge — laisse le bleu fonctionner.

```lua
-- en cours de mission, réseau par réseau
veafSkynet.setDynamicSpawn("red iads", false)
```

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

## Désactivation d'un réseau {#deactivation}

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

**Un réseau désactivé reste désactivé.** Faire apparaître un SAM dedans ne le rallume plus : le groupe est bien rattaché — c'est ce que demande `skynet true` — mais le réseau ne se réveille pas tout seul. Avant, l'apparition d'un seul SAM suffisait à remettre en route un réseau qu'on venait d'éteindre.

Pour le rallumer, il faut le demander. Tout ce qui a été rattaché entre-temps s'allume avec lui :

```lua
veafSkynet.activateNetworkOfCoalition(coalition.side.RED)
```

Désactiver un réseau **ne touche pas à l'autre** : le réseau bleu garde son état et son intégration des apparitions.

---

## Accéder aux réseaux générés

Après l'initialisation (qui se fait en différé), on peut accéder aux objets réseaux Skynet via une tâche différée :

```lua
local assignRedIadsTaskId = nil
local myRedIads = nil

local function AssignRedIadsTask()
    if not veafSkynet then
        veaf.removeFunction(assignRedIadsTaskId)
        return
    end
    if veafSkynet.initialized then
        veaf.removeFunction(assignRedIadsTaskId)
        local veafSkynetNetwork = veafSkynet.getNetwork(veafSkynet.defaultIADS[tostring(coalition.side.RED)])
        myRedIads = veafSkynetNetwork.iads
    end
end

assignRedIadsTaskId = veaf.scheduleFunction(AssignRedIadsTask, {}, timer.getTime() + veafSkynet.DelayForStartup + 1, 10)
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

> Cet exemple appelle `mist.cloneInZone`, il a donc besoin de MiST — qui n'est plus injecté dans
> toutes les missions. Placez l'extrait dans l'un de vos `src/scripts/*.lua` et le build voit l'appel
> `mist.` et injecte MiST pour vous ; voir
> [MiST : injecté seulement si vous en avez besoin](../GUIDE.md#mist-injection).

---

## Voir aussi

- [Documentation Skynet IADS](https://github.com/walder/Skynet-IADS) — script tiers (non inclus dans VEAF)
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafSkynet`
