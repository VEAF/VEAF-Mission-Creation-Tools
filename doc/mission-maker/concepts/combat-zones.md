# Zones de combat

## Ce que c'est {#what-it-is}

Un objectif préparé dans l'éditeur DCS et **activable à la demande** depuis le menu radio F10. Au
démarrage la zone est vidée : ses groupes sont détruits. À l'activation, ils sont recréés, et la
zone se déclare terminée quand l'ennemi n'est plus là.

Une zone se déclare en trois morceaux, deux dans l'éditeur DCS et un dans `mission.yaml`.

## Le plus petit exemple qui marche {#minimal-example}

**1. Dans l'éditeur DCS** — une trigger zone nommée `CZ-Alpha`.

**2. Dans l'éditeur DCS** — un groupe placé dedans, nommé `CZ-Alpha-ARMOR`.

**3. Dans `mission.yaml`** :

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - zone_name: CZ-Alpha
        friendly_name: Zone Alpha
        training: true
```

`zone_name` est la seule clé obligatoire ; c'est le nom de la trigger zone, au caractère près.
`friendly_name` est ce que le joueur lit dans le menu ; sans elle, il lit `zone_name`.

En jeu : **F10 « Other » → ZONES DE COMBAT → Zone Alpha → Activer la zone**. Le message
« VeafCombatZone Zone Alpha a été activé. » s'affiche, le contenu apparaît une seconde plus tard, et
le rapport de zone suit.

## Le piège {#gotcha}

**Le nom du groupe doit commencer par le nom de la zone.** Placer un groupe dans la trigger zone ne
suffit pas : la zone ne capture que les groupes dont le nom **commence par** son propre nom (la
casse est ignorée). Un groupe `ARMOR-1` bien placé dans `CZ-Alpha` est purement ignoré ; il faut
`CZ-Alpha-ARMOR-1`.

Corollaire dangereux dans l'autre sens : un groupe sans rapport nommé `CZ-Alpha-quelque-chose` et
posé dans la zone sera détruit au démarrage de la mission.

Deuxième piège : `training: true` n'est pas cosmétique. Sans lui, l'entrée du menu s'affiche
`+Activer la zone` et exige une radio authentifiée — pratique sur un serveur, déroutant quand on
découvre.

## `training: true` ou pas {#training}

| | entrée de menu | qui peut activer |
|---|---|---|
| `training: true` | `Activer la zone` | tout le monde |
| absent ou `false` | `+Activer la zone` | seulement une radio authentifiée ([sécurité](../scripts/veafSecurity.md)) |

## Faire apparaître des unités VEAF plutôt que des unités posées à la main {#command-units}

Plutôt que de placer les unités une à une, posez une unité factice dont le **nom** porte une
commande VEAF. Elle est détruite au démarrage, et la commande s'exécute à l'activation :

```
CZ-Alpha-SAM #command="-samLR"
```

L'alias (`-samLR`, `-samSR`, `-armor`…) vient du [catalogue des alias](../../ALIASES.md) — il n'y a
pas de `-lrsam`, c'est `-samLR`.

## Doser l'aléatoire {#randomness}

Des marqueurs dans les noms règlent le comportement de l'apparition :

| Marqueur | Effet | Défaut |
|---|---|---|
| `#spawnchance=50` | ce groupe a 50 % de chances d'apparaître | 100 |
| `#spawncount=2` | exactement 2 groupes parmi ceux de la zone | 1 |
| `#spawnradius=200` | dispersion aléatoire, en mètres | 50 m (groupe), 0 m (statique) |
| `#spawndelay=60` | apparition différée, en secondes | aucun délai |

!!! warning "Ceci change les missions existantes"
    `#spawnchance` **refuse réellement** une apparition : un groupe à 50 % apparaît une fois sur
    deux, et un groupe à 0 % n'apparaît jamais. La garantie de nombre reste à `#spawncount` : deux
    groupes demandés parmi quatre en donnent exactement deux, tirés au hasard. Les missions qui
    utilisaient `#spawnchance` verront donc **moins** d'apparitions qu'avant.

## Pour aller plus loin {#more}

- [veafCombatZone — la règle du préfixe, en détail](../scripts/veafCombatZone.md#zone-membership)
- [veafCombatZone — configuration complète](../scripts/veafCombatZone.md#configuration-missionyaml)
- [veafCombatZone — tous les marqueurs de nom](../scripts/veafCombatZone.md#spawn-radius)
- [veafCombatZone — où les marqueurs sont lus](../scripts/veafCombatZone.md#tag-sources)
- [veafCombatZone — à qui le menu F10 est proposé](../scripts/veafCombatZone.md#f10-menu-audience)
- [Alias de marqueurs](../../ALIASES.md)
