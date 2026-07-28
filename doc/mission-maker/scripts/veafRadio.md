# veafRadio — Gestionnaire du menu radio F10


**Module ID :** `RADIO` | **Fichier :** `veafRadio.lua`

---

## Objectif

Le menu "Autre" F10 de DCS est l'interface principale entre les joueurs et les scripts VEAF. `veafRadio` gère l'intégralité de cet arbre de menus : sa construction, son rafraîchissement à mesure que les groupes humains rejoignent et quittent la mission, et fournit des helpers qui permettent aux autres modules VEAF et aux créateurs de missions d'ajouter leurs propres entrées sans se soucier des limites du menu radio DCS.

---

## Activation

```lua
veafRadio.initialize()
```

Paramètres optionnels :

```lua
veafRadio.initialize(
  skipHelpMenus,   -- bool : omettre les entrées "Aide" des menus intégrés (défaut false)
  dontCreateMenus  -- bool : supprimer toute création de menu radio DCS (défaut false)
)
```

Après l'initialisation de tous les modules, appeler :

```lua
veafRadio.refreshRadioMenu()
```

Cela reconstruit l'intégralité de l'arbre F10. L'appel est idempotent — il gère en interne un délai anti-rebond de 1 seconde.

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

```yaml
modules:
  RADIO:
    enabled: true          # défaut : true
    logLevel: info        # surcharge optionnelle du niveau de log
    init:
      help_menus: true    # afficher les entrées "Aide" intégrées dans les menus radio (défaut : true)
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `enabled` | booléen | `true` | Non | Activer ou désactiver le module |
| `logLevel` | string | *(global)* | Non | Surcharge du niveau de log par module |
| `init.help_menus` | booléen | `true` | Non | Afficher les entrées "Aide" intégrées dans les menus radio générés |

### Exemple minimal

```yaml
modules:
  RADIO:
    enabled: true
```

---

## Créer un menu personnalisé

Utilisez `veafRadio.createUserMenu()` pour construire un arbre de menus structuré à partir d'une simple table Lua, en utilisant trois helpers :

```lua
veafRadio.createUserMenu(
  veafRadio.mainmenu(
    veafRadio.menu("Gestion QRA",
      veafRadio.command("Démarrer QRA Nord", maMission.demarrerQra, { name = "QRA-NORD" }),
      veafRadio.command("Arrêter QRA Nord",  maMission.arreterQra,  { name = "QRA-NORD" })
    ),
    veafRadio.menu("Flags",
      veafRadio.command("Activer Flag 10",   trigger.action.setUserFlag, { "FLAG-10", true }),
      veafRadio.command("Désactiver Flag 10", trigger.action.setUserFlag, { "FLAG-10", false })
    )
  )
)
```

### Helpers

| Helper | Signature | Retourne |
|--------|-----------|---------|
| `mainmenu(...)` | Arguments variables de `menu()` ou `command()` | Tableau plat pour `createUserMenu()` |
| `menu(name, ...)` | Nom + arguments variables d'éléments imbriqués | Nœud de sous-menu |
| `command(name, fn, params)` | Nom + fonction + table de paramètres | Nœud de commande |

### Menus spécifiques à un groupe

Passer un `groupId` comme second argument de `createUserMenu()` — le menu n'apparaîtra que pour ce groupe :

```lua
local groupIdJoueur = 101
veafRadio.createUserMenu(
  veafRadio.mainmenu(
    veafRadio.command("Demander ravitailleur", maMission.demanderRavitailleur, { groupId = groupIdJoueur })
  ),
  groupIdJoueur
)
```

> **Lua vs YAML.** `veafRadio.createUserMenu(configuration, groupId)` est du **Lua** : il se place dans `mission-script.lua`. Depuis ADR 0011, la même chose se déclare directement en YAML sous `modules.RADIO.user_menus` (voir [Menus radio en YAML](#menus-radio-en-yaml)), sans écrire de Lua. L'action YAML `lua` reste le pont pour rattacher une fonction Lua écrite par le créateur de mission à un menu déclaré en YAML.

---

## Menus radio en YAML {#radio-menus-in-yaml}

Depuis ADR 0011, un créateur de mission peut déclarer un menu radio F10 personnalisé **entièrement en YAML**, sans écrire de Lua, sous `modules.RADIO.user_menus`. C'est le pendant déclaratif de `veafRadio.createUserMenu()` (voir l'encart ci-dessus), destiné notamment aux menus de contrôle du Mission Master (MM).

```yaml
modules:
  RADIO:
    user_menus:
      restrict_to_group: "MM Ctrl"   # optionnel : nom d'un groupe DCS ; le menu n'apparaît que pour ce groupe. Absent = menu global.
      tree:
        - menu: "Contrôle QRA"
          items:
            - { command: "Démarrer QRA Nord", action: qra.start, qra: "QRA-Nord" }
            - { command: "Arrêter QRA Nord",  action: qra.stop,  qra: "QRA-Nord" }
        - menu: "Phases"
          items:
            - { command: "Activer Phase 2",   action: flag.on,  flag: "PHASE2" }
            - { command: "Régler compteur",   action: flag.set, flag: "SCORE", value: 100 }
        - { command: "Message global", action: message, text: "La mission commence !" }
        - { command: "Fonction custom", action: lua, function: "maMission.demarrerTout", args: ["alpha", 3] }
```

### Structure de `tree`

Chaque nœud de `tree` est **soit un sous-menu, soit une commande** :

- **Sous-menu** — `{ menu: "Titre", items: [ ... ] }`. Le champ `items` contient à son tour des sous-menus ou des commandes ; l'imbrication est récursive.
- **Commande** — `{ command: "Libellé", action: <verbe>, <clés cibles> }`. Placée directement dans `tree` (premier niveau) ou dans les `items` d'un sous-menu.

### `restrict_to_group`

`restrict_to_group` est **optionnel**. S'il est présent, le menu n'apparaît que pour le groupe DCS nommé (par exemple un groupe de contrôle « MM Ctrl »). Absent, le menu est global et visible par tous les joueurs.

### Vocabulaire d'actions

Le vocabulaire d'actions est **fermé** (v1). Chaque `action` requiert les clés indiquées :

| `action` | Clés requises | Effet |
|----------|---------------|-------|
| `qra.start` | `qra: "<nom de la QRA>"` | Met en ligne la QRA nommée |
| `qra.stop` | `qra: "<nom de la QRA>"` | Met hors ligne la QRA nommée |
| `airwave.start` | `airwave: "<nom de la zone AirWave>"` | Démarre la zone AirWave nommée |
| `airwave.stop` | `airwave: "<nom de la zone AirWave>"` | Arrête la zone AirWave nommée |
| `airwave.reset` | `airwave: "<nom de la zone AirWave>"` | Réinitialise la zone AirWave nommée |
| `flag.on` | `flag: "<nom ou numéro de flag>"` | Met le flag à `1` |
| `flag.off` | `flag: "<nom ou numéro de flag>"` | Met le flag à `0` |
| `flag.set` | `flag`, `value` (entier) | Met le flag à la valeur entière donnée |
| `flag.increment` | `flag` | Incrémente le flag de `1` |
| `flag.decrement` | `flag` | Décrémente le flag de `1` |
| `message` | `text: "<texte affiché>"` | Affiche le texte à l'écran |
| `lua` | `function: "<nom.de.fonction>"`, `args: [ ... ]` (optionnel) | Appelle une fonction Lua du créateur de mission |

> **L'action `lua` est le pont vers votre Lua.** La fonction référencée par `function:` doit être définie par le créateur de mission dans `mission-script.lua`. Si elle est référencée en YAML mais **absente** du Lua de la mission, **le build échoue** (et `veaf-tools validate` la signale). C'est le moyen de rattacher une fonction Lua personnalisée à un menu déclaré en YAML.

---

## Constantes d'utilisation

Lors de l'ajout de commandes via l'API bas niveau, le paramètre `usage` contrôle qui voit l'entrée :

| Constante | Valeur | Comportement |
|-----------|--------|-------------|
| `veafRadio.USAGE_ForAll` | `0` | Entrée unique visible pour tous les joueurs |
| `veafRadio.USAGE_ForGroup` | `1` | Une entrée par groupe humain connecté ; le nom de l'unité est ajouté automatiquement aux paramètres |
| `veafRadio.USAGE_ForUnit` | `2` | Une entrée par pilote humain connecté ; le titre est préfixé avec l'indicatif du pilote |

`USAGE_ForGroup` est idéal pour les commandes qui doivent répondre différemment par vol (ex : "Demander appui pour mon vol"). `USAGE_ForUnit` est pour les interactions individuelles par pilote.

---

## Réserver un menu à une coalition {#coalition-scoped-menus}

`usage` décide **qui reçoit une commande**. Pour masquer un **sous-menu entier** à l'autre camp,
passez une coalition en troisième argument de `addSubMenu` :

```lua
-- ce sous-menu, et tout ce qu'il contient, n'existe que pour les rouges
local menuRouge = veafRadio.addSubMenu("Zones ROUGE", nil, coalition.side.RED)
veafRadio.addCommandToSubmenu("Statut", menuRouge, maFonction, nil, veafRadio.USAGE_ForGroup)
```

Trois conséquences, automatiques :

- **l'appartenance est héritée** — sous-menus, commandes et pages de pagination créées quand le
  menu dépasse `MENU_PAGE_SIZE` ; il n'y a pas d'enfant « visible par tous » sous un menu réservé ;
- une commande `USAGE_ForGroup` ou `USAGE_ForUnit` n'est posée que pour les groupes **de ce camp**
  (un groupe dont DCS ne nous donne pas la coalition est conservé) ;
- le menu est reconstruit à chaque connexion de joueur, et les menus réservés sont retirés
  explicitement à ce moment-là — sans quoi ils s'empileraient en double à chaque arrivée.

Le menu **parent** n'est pas modifié : si vous accrochez un menu réservé sous un menu global,
l'autre camp continue de voir le parent, simplement vide de cette entrée.

> Utilisé par les zones de combat, qui proposent leur menu au camp qui les joue — voir
> [veafCombatZone](veafCombatZone.md#f10-menu-audience).

---

## API bas niveau

Pour un contrôle plus fin, construire l'arbre de menus directement :

```lua
-- Ajouter un sous-menu de premier niveau sous la racine VEAF
local menuMission = veafRadio.addMenu("Contrôle Mission")

-- Ajouter un sous-menu à l'intérieur
local menuQra = veafRadio.addSubMenu("QRA", menuMission)

-- Ajouter une commande (ForAll)
veafRadio.addCommandToSubmenu(
  "Démarrer QRA Nord",
  menuQra,
  maMission.demarrerQra,
  { name = "QRA-NORD" },
  veafRadio.USAGE_ForAll
)

-- Ajouter une commande sécurisée (nécessite /secu login)
veafRadio.addSecuredCommandToSubmenu(
  "Arrêt d'urgence",
  menuMission,
  maMission.arretUrgence,
  {},
  veafRadio.USAGE_ForAll
)

-- Déclencher une reconstruction
veafRadio.refreshRadioMenu()
```

### Pagination automatique

DCS tronque un sous-menu au-delà de **10 entrées**. Vous n'avez rien à faire :
tout menu radio dépassant cette limite est **paginé automatiquement au rendu**.
Les entrées en trop sont réparties dans des sous-menus « Page suivante » créés à la
demande — inutile d'appeler un helper de pagination. Un menu qui tient en 10 entrées
n'a pas de « Page suivante » (aucun slot gaspillé).

Pour **désactiver** la pagination sur un menu précis :

```lua
veafRadio.doNotPaginate(monMenu)
```

Cas particulier : un menu contenant une commande `USAGE_ForUnit` (une entrée par
appareil du groupe) désactive sa pagination automatiquement, avec un avertissement
dans le log — le découpage global ne pourrait pas garantir la limite par groupe.

> La taille de page est fixée à la limite DCS (`veafRadio.MENU_PAGE_SIZE = 10`).
> Les helpers `addPaginatedRadioElements` / `addPaginatedRadioMenu` existent toujours
> (ils trient et insèrent les éléments) mais ne paginent plus eux-mêmes : le rendu
> s'en charge.

---

## Exemples pratiques de fonctions de callback

Les commandes d'un menu utilisateur appellent une fonction Lua. Voici des exemples courants :

### Démarrer / arrêter une QRA

```lua
local function _changeQra(parameters)
    local name, action = veaf.safeUnpack(parameters)
    local qra = veafQraManager.get(name)
    if qra then
        if action:upper() == "START" then
            qra:start(false)
        else
            qra:stop(false)
        end
    end
end

veafRadio.createUserMenu(
    veafRadio.mainmenu(
        veafRadio.menu("Gestion QRA",
            veafRadio.menu("QRA Maykop",
                veafRadio.command("START", _changeQra, {"QRA-Maykop", "start"}),
                veafRadio.command("STOP",  _changeQra, {"QRA-Maykop", "stop"})
            )
        )
    )
)
```

### Détruire un groupe par son nom

```lua
local function _destroyGroup(name)
    local names = type(name) == "string" and {name} or name
    for _, n in pairs(names) do
        local g = Group.getByName(n)
        if g then
            g:destroy()
            trigger.action.outText(string.format("Group %s destroyed", n), 10)
        end
    end
end

veafRadio.createUserMenu(
    veafRadio.mainmenu(
        veafRadio.menu("Adversaires",
            veafRadio.command("CAP Maykop",  _destroyGroup, "CAP-Maykop"),
            veafRadio.command("SA-6 Minvody", _destroyGroup, "SA6-Minvody")
        )
    )
)
```

### Gérer des drapeaux DCS (pour déclencher des triggers)

```lua
veafRadio.createUserMenu(
    veafRadio.mainmenu(
        veafRadio.menu("Flags",
            veafRadio.command("Flag ALPHA ON",  veafSpawn.missionMasterSetFlagFromTable,       {"alpha", 1}),
            veafRadio.command("Flag ALPHA OFF", veafSpawn.missionMasterSetFlagFromTable,       {"alpha", 0}),
            veafRadio.command("Incrémenter 127", veafSpawn.missionMasterIncrementFlagValue,   127),
            veafRadio.command("Décrémenter 127", veafSpawn.missionMasterDecrementFlagValue,   127)
        )
    )
)
```

### Commande par groupe (ForGroup)

Une entrée « Demander un appui aérien » qui apparaît une fois par patrouille connectée, en passant automatiquement le nom d'unité de ce groupe :

```lua
veafRadio.addCommandToSubmenu(
  "Request CAS",
  supportMenu,
  myCasDispatch,      -- reçoit { originalParams, unitName } à l'exécution
  {},
  veafRadio.USAGE_ForGroup
)
```

---

## Voir aussi

- [veafSecurity](veafSecurity.md) — sécuriser les commandes avec `/secu login`
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafRadio`
