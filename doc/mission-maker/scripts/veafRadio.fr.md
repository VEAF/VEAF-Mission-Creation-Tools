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
lua_modules:
  RADIO:
    enable: true          # défaut : true
    logLevel: info        # surcharge optionnelle du niveau de log
    init:
      help_menus: true    # afficher les entrées "Aide" intégrées dans les menus radio (défaut : true)
```

| Champ | Type | Défaut | Requis | Description |
|-------|------|--------|--------|-------------|
| `enable` | booléen | `true` | Non | Activer ou désactiver le module |
| `logLevel` | string | *(global)* | Non | Surcharge du niveau de log par module |
| `init.help_menus` | booléen | `true` | Non | Afficher les entrées "Aide" intégrées dans les menus radio générés |

### Exemple minimal

```yaml
lua_modules:
  RADIO:
    enable: true
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

---

## Voir aussi

- [veafSecurity](veafSecurity.md) — sécuriser les commandes avec `/secu login`
- [Référence API Lua](../../LUA_API_REFERENCE.md) — API complète de `veafRadio`
