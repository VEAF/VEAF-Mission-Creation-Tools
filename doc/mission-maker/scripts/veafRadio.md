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

## Configuration (`mission.yaml`)

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
      veafRadio.command("Démarrer QRA Nord", veafQraManager.startQra, { name = "QRA-NORD" }),
      veafRadio.command("Arrêter QRA Nord",  veafQraManager.stopQra,  { name = "QRA-NORD" }),
      veafRadio.command("Statut",            veafQraManager.getStatus,{ name = "QRA-NORD" })
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
  veafQraManager.startQra,
  { name = "QRA-NORD" },
  veafRadio.USAGE_ForAll
)

-- Ajouter une commande sécurisée (nécessite /secu login)
veafRadio.addSecuredCommandToSubmenu(
  "Arrêt d'urgence tous les QRA",
  menuMission,
  veafQraManager.stopAll,
  {},
  veafRadio.USAGE_ForAll
)

-- Déclencher une reconstruction
veafRadio.refreshRadioMenu()
```

### Menus paginés

Quand un sous-menu compte plus d'environ 9 entrées (limite DCS), utilisez les helpers paginés :

```lua
veafRadio.addPaginatedRadioMenu(
  "All Zones",          -- titre du menu
  parentMenu,           -- nœud du menu parent
  veafRadio.addCommandToSubmenu,
  myZonesList,          -- table d'éléments
  "name",               -- attribut utilisé comme titre d'entrée
  "sortKey"             -- attribut utilisé pour le tri (optionnel)
)
```

Des pages de 10 sont créées automatiquement avec un sous-menu « Page suivante ».

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
