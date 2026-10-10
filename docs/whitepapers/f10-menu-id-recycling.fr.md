# DCS : quand un menu F10 resté ouvert déclenche la mauvaise commande

*Whitepaper VEAF à l'intention des auteurs de scripts de mission DCS World. Le document décrit un comportement de l'API `missionCommands`, mesuré en jeu, et la manière de construire un menu F10 qui y résiste, avec en exemples VEAF Mission Creation Tools (VMCT) et CTLD.*
*Rédigé le 2026-10-10 à partir des mesures du 2026-10-09.*
*English version: [f10-menu-id-recycling.en.md](f10-menu-id-recycling.en.md).*

## Résumé

**DCS suit chaque entrée du menu F10 par un identifiant interne, redonne l'identifiant d'une entrée supprimée à la prochaine entrée créée, et ne rafraîchit pas un écran F10 resté ouvert.**
Quand un script reconstruit un menu pendant qu'un joueur le lit, le clic du joueur part vers l'entrée qui a hérité de l'identifiant, c'est-à-dire une autre commande.
Ces identifiants forment un seul stock pour tout le serveur : un clic périmé peut même déclencher la commande d'un autre groupe.

Retarder la reconstruction ne protège pas, puisque l'écran périmé survit au délai.
Ce qui protège, c'est de construire le menu autrement :

1. **rendre par différence** : ne jamais supprimer ni recréer une entrée qui n'a pas changé ;
2. **garer chaque identifiant libéré** : juste après chaque suppression, créer une commande inerte pour un groupe que personne ne peut occuper, qui absorbe l'identifiant ;
3. **ne jamais déplacer une entrée**, ce qui revient à la supprimer et la recréer ; en particulier, garder les pages stables dans un menu paginé.

VMCT et CTLD appliquent ce patron depuis le 2026-10-09.

## 1. Le menu F10 vu d'un script

Un script de mission construit le menu F10 avec l'API `missionCommands` :

- `addSubMenu`, `addSubMenuForCoalition`, `addSubMenuForGroup` créent un sous-menu, sans callback ;
- `addCommand`, `addCommandForCoalition`, `addCommandForGroup` créent une commande, qui appelle sa fonction quand le joueur la sélectionne ;
- `removeItem`, `removeItemForCoalition`, `removeItemForGroup` suppriment une entrée et tout ce qu'elle contient.

Chaque fonction de création renvoie un chemin, à passer ensuite comme parent ou à `removeItem`.

Deux propriétés de l'API comptent pour la suite :

- **DCS ne prévient pas le script quand un joueur ouvre le menu ou navigue dedans.** Seule la sélection d'une commande appelle du code. Un script ne sait donc jamais qui a un menu sous les yeux.
- **Il n'existe aucune fonction pour modifier une entrée.** Changer le libellé, la fonction ou les paramètres d'une commande impose de la supprimer et d'en créer une autre.

Beaucoup de scripts en tirent la solution la plus simple : à chaque changement d'état, supprimer tout le menu et le reconstruire.
C'est précisément ce qui déclenche le défaut.

## 2. Le symptôme

En multijoueur, un joueur ouvre F10 et descend dans un sous-menu.
Pendant qu'il lit, le script reconstruit les menus, parce qu'un autre joueur vient d'arriver ou qu'une zone a changé d'état.
L'écran du joueur ne bouge pas.
Il clique, et une autre commande part.

Sur les serveurs VEAF, le défaut a été signalé dans CTLD, par exemple un fumigène rouge déclenché à la place d'un embarquement de troupes, et plus rarement dans les menus VEAF.
Il est intermittent, puisqu'il faut qu'une reconstruction tombe entre l'ouverture du menu et le clic, et il est difficile à reproduire, puisque le joueur ne sait pas quand le script reconstruit.

## 3. Ce que fait DCS, mesuré

### 3.1 Le dispositif

Pour mesurer DCS lui-même, sans le code d'aucun outil, le test n'utilise que `missionCommands` :

- un menu `TEST MENU > Liste` contenant quatre commandes A, B, C, D, chacune écrivant son libellé à l'écran et dans `dcs.log` ;
- le changement est appliqué depuis l'extérieur de la mission, par un hook de console Lua, pendant que le joueur garde `Liste` ouvert ;
- DCS en solo, **mission redémarrée avant chaque test**, clics à la souris.

Un **témoin** sans aucun changement (clic sur B → B) vérifie que le dispositif lui-même ne fausse rien.

Le script d'installation, chargé dans n'importe quelle mission :

```lua
RT = { gen = 0, cmds = {} }
function RT.click(p)
  env.info("RADIOTEST click " .. p.label .. " gen " .. p.gen)
  trigger.action.outText("CLIC RECU : " .. p.label .. " (generation " .. p.gen .. ")", 20)
end
function RT.add(label, path)
  return missionCommands.addCommand(label, path, RT.click, { label = label, gen = RT.gen })
end
function RT.fillList(items)
  RT.gen = RT.gen + 1
  RT.cmds = {}
  for _, l in ipairs(items) do RT.cmds[#RT.cmds + 1] = RT.add(l, RT.list) end
end
RT.root = missionCommands.addSubMenu("TEST MENU")
RT.list = missionCommands.addSubMenu("Liste", RT.root)
RT.fillList({ "A", "B", "C", "D" })
```

Le test 1, appliqué pendant que le joueur garde `Liste` ouvert, avant un clic sur B :

```lua
for _, c in ipairs(RT.cmds) do missionCommands.removeItem(c) end
RT.fillList({ "A", "B", "C", "D" })
```

Le test 9, avant un clic sur B (9a) ou sur A (9b) :

```lua
missionCommands.removeItem(RT.cmds[1])
RT.cmds[1] = RT.add("E", RT.list)
```

### 3.2 Les résultats

| # | Changement pendant que la liste est affichée | Clic | Résultat |
|---|---|---|---|
| témoin | aucun | B | B ✅ |
| 1 | suppression puis recréation de A, B, C, D, à l'identique | B | **C** ❌ |
| 7 | suppression de A, puis ajout de X et Y ailleurs ; menu rouvert à neuf | X, Y | X, Y ✅ |
| 9a | suppression de A, puis ajout de E | B | B ✅ |
| 9b | suppression de A, puis ajout de E | A | **E** ❌ |
| P2c | même chose dans un menu de groupe (`ForGroup`) | A | **E** ❌ |
| P1 | menu global : suppression de A, ajout d'une commande pour un groupe inexistant, puis ajout de E | A | la commande inerte ✅ |
| P2 | menu de groupe : même séquence que P1 | A | la commande inerte ✅ |

Une première série, moins contrôlée, va dans le même sens :

| Changement pendant que la liste est affichée | Clic | Résultat |
|---|---|---|
| suppression puis recréation de tout `TEST MENU` | B | **« Test 2 », une entrée d'un autre menu** ❌ |
| ajout de E en fin de liste | B | B ✅ |
| suppression de D, après B | B | B ✅ |
| suppression de A, avant B | B | B ✅ |
| suppression de A, rien créé ensuite | A | rien ✅ |

Le cas « suppression de A, avant B » écarte l'hypothèse la plus naturelle : si DCS résolvait le clic par sa position dans la liste, F2 serait tombé sur C.
Il est tombé sur B.

### 3.3 Le modèle qui explique toutes les mesures

DCS attribue un identifiant interne à chaque entrée.
L'écran F10 du joueur garde les identifiants des entrées qu'il affiche, et n'est pas rafraîchi tant qu'il reste ouvert.
Quand une entrée est supprimée, son identifiant est libéré, et **la prochaine entrée créée le récupère**.

L'ordre de réutilisation observé est cohérent avec « dernier libéré, premier réutilisé ».
Il explique exactement le test 1 :

| Entrée | Identifiant avant | Libéré | Identifiant après recréation |
|---|---|---|---|
| A | 1 | en 1ᵉʳ | 4 |
| B | 2 | en 2ᵉ | 3 |
| C | 3 | en 3ᵉ | **2** |
| D | 4 | en 4ᵉ | 1 |

L'écran du joueur associe toujours l'identifiant 2 à B ; l'identifiant 2 appartient maintenant à C ; le clic sur B déclenche C.
Cet ordre reste une inférence : seuls ses effets ont été mesurés.

Les tests P1 et P2 établissent un fait plus grave : **les identifiants forment un seul stock pour tout le serveur.**
L'identifiant d'une entrée du menu global est passé à une commande créée pour un autre groupe.
Un clic périmé peut donc déclencher la commande d'un autre groupe, y compris une commande réservée, qui s'exécute alors avec les paramètres de ce groupe.

### 3.4 Ce qui est sûr, ce qui ne l'est pas

| Opération pendant qu'un joueur lit le menu | Effet sur son clic |
|---|---|
| ne rien toucher | juste |
| ajouter une entrée | juste, pour toutes les entrées affichées |
| supprimer une entrée, sans rien créer ensuite | juste pour les autres ; rien pour l'entrée supprimée |
| supprimer une entrée, puis en créer une autre, n'importe où sur le serveur | **le clic sur l'entrée supprimée déclenche la nouvelle** |
| reconstruire tout le menu, même à l'identique | **n'importe quel clic peut partir ailleurs** |
| rouvrir le menu après le changement | toujours juste |

### 3.5 Un piège de mesure

Une première série de tests, empilés dans le même menu sans redémarrer la mission, a produit un résultat alarmant : un menu rouvert à neuf semblait déclencher la mauvaise commande.
Refait sur une mission redémarrée, le test ne s'est pas reproduit.
Les manipulations précédentes avaient laissé le stock d'identifiants dans un état que le test ne contrôlait pas.
**Toute mesure de ce comportement se fait sur une mission redémarrée, un test à la fois**, avec un témoin.

## 4. Pourquoi les parades habituelles échouent

| Parade | Pourquoi elle ne suffit pas |
|---|---|
| Reconstruire le menu dans le même ordre | Le test 1 reconstruit à l'identique et fait partir C au lieu de B : ce n'est pas la position qui compte. |
| Retarder la reconstruction : vider le menu tout de suite, le reconstruire quelques secondes plus tard | Un clic pendant le délai ne fait rien, mais l'écran du joueur reste figé au-delà du délai ; un clic après la reconstruction retombe sur le défaut. La fenêtre rétrécit, elle ne se ferme pas. |
| Regrouper les reconstructions rapprochées (debounce) | Utile pour le nombre d'appels, sans effet sur le mécanisme : chaque reconstruction réattribue tous les identifiants. |
| Ne reconstruire que le menu du groupe concerné | Le stock d'identifiants est commun à tout le serveur : les identifiants libérés par un groupe sont repris par les créations d'un autre. |

CTLD avait adopté la deuxième parade en septembre 2026, et les joueurs continuaient à signaler des commandes erronées : c'est ce qui a déclenché la mesure.

## 5. Le correctif générique

### 5.1 Rendre par différence

Le script garde en mémoire ce qu'il a rendu la fois précédente.
À chaque rafraîchissement, il compare le menu voulu au menu rendu, crée ce qui est apparu, supprime ce qui a disparu, et ne touche pas au reste.

Chaque entrée reçoit une **clé stable**, qui doit identifier la même entrée d'un rendu à l'autre :

- la clé de son parent ;
- son audience : tout le monde, une coalition ou un groupe ;
- sa nature : sous-menu ou commande ;
- son libellé, suffixé de `#2`, `#3`… quand deux entrées portent le même libellé sous un même parent.

Une entrée de même clé est réutilisée telle quelle si sa fonction et ses paramètres n'ont pas changé : aucun appel à DCS.
Sinon, elle est supprimée puis recréée.
Les entrées qui ont disparu sont supprimées **les enfants avant leur parent**, pour que chaque identifiant libéré soit garé un par un.

Trois pièges guettent la comparaison :

- **Une fonction recréée à chaque rafraîchissement n'est jamais égale à la précédente.** Une closure construite dans la boucle de rendu fait recréer toutes les commandes, à chaque fois. Il faut des fonctions stables, ou un point d'entrée unique qui reçoit une clé et retrouve la bonne action au moment du clic.
- **Un objet DCS n'est jamais égal à lui-même d'un appel à l'autre.** `Unit.getByName` renvoie une nouvelle table à chaque appel. Deux objets DCS se comparent par leur classe et leur identifiant `id_`.
- **Une table de paramètres reconstruite n'est pas la même table.** La comparer champ par champ, ou passer des valeurs simples.

### 5.2 Garer chaque identifiant libéré

Le rendu par différence règle la reconstruction complète, mais pas le remplacement : une entrée qui disparaît pendant qu'une autre apparaît (une zone « Activer » qui devient « Désactiver ») suffit à faire hériter l'identifiant, test 9b.

La parade : **juste après chaque suppression, et avant toute autre création, créer une commande inerte pour un groupe que personne ne peut occuper.**

```lua
missionCommands.removeItem(path)
missionCommands.addCommandForGroup(999999, "parked " .. n, nil, onParkedClick)
```

La commande prend l'identifiant libéré ; personne ne la voit, puisqu'aucun joueur n'appartient au groupe 999999 ; un clic périmé sur l'entrée supprimée atterrit sur elle et ne fait rien.
Le stock étant commun à tout le serveur, une commande de groupe gare l'identifiant d'une entrée globale comme celui d'une entrée de groupe : les tests P1 et P2 l'ont mesuré.
Pour une entrée de coalition, c'est très probable mais pas mesuré.

Le coût : une commande invisible par suppression, jamais retirée, qui s'accumule donc pendant toute la mission.
Il a été mesuré le 2026-10-10, en solo, en garant jusqu'à 50 000 commandes dans une mission en cours :

| Commandes garées | Temps de création | Mémoire privée de DCS | Images par seconde | 500 créations + 500 suppressions ordinaires | Menu F10 |
|---|---|---|---|---|---|
| 0 | | 29 465 Mo | 30,0 | 0,096 s | instantané |
| 1 000 | 0,05 s | 29 373 Mo | 30,0 | 0,029 s | instantané |
| 10 000 | 0,02 s | 29 356 Mo | 30,0 | 0,025 s | instantané |
| 50 000 | 0,13 s | 29 443 Mo | 30,0 | 0,065 s | instantané |

Rien n'est mesurable : ni la mémoire de DCS, dont le bruit est d'environ 100 Mo, soit moins de 2 Ko par commande ; ni les images par seconde ; ni la vitesse des opérations ordinaires, qui ne ralentissent pas quand le menu grossit.
La mémoire Lua de la mission est passée de 46 à 66 Mo, soit au plus 0,4 Ko par commande, ramasse-miettes compris.
Une longue mission devrait garer quelques milliers de numéros au plus : c'est une estimation, non mesurée, mais elle reste dix fois sous le palier testé.
Il n'y a pas lieu de borner le stock.

### 5.3 L'ordre des entrées

DCS ajoute toujours une entrée nouvelle à la fin de son menu.
Insérer une entrée au milieu d'une liste triée oblige donc à recréer toutes celles qui la suivent.
Grâce au parking, c'est devenu sans danger : un clic périmé sur une entrée recréée ne fait rien, au pire.

Deux choix restent possibles, selon ce que le menu promet au joueur :

| Choix | Pour | Contre |
|---|---|---|
| Ajouter en fin de liste | aucune entrée existante ne bouge, le clic reste juste | la liste n'est triée qu'au premier affichage |
| Recréer les entrées qui suivent l'insertion | l'ordre déclaré est respecté | ces entrées deviennent inertes pour un écran périmé |

### 5.4 Les menus paginés

DCS tronque un sous-menu au-delà de dix entrées, d'où la pagination par une commande « Page suivante ».
Si la page de chaque entrée est recalculée à chaque rendu, un ajout en tête décale toutes les suivantes, et chaque entrée qui change de page est supprimée puis recréée.
Une entrée nouvelle peut même atterrir après « Page suivante ».

La parade est de **garder les pages stables** :

- au premier affichage, distribuer les entrées dans l'ordre ;
- ensuite, une entrée déjà affichée garde sa page, et une entrée nouvelle va sur la dernière page ;
- une page vidée disparaît, les suivantes remontent ;
- un menu qui retombe sous la taille d'une page revient sur une seule page.

### 5.5 Un squelette

Ce squelette applique les sections 5.1 et 5.2 à un menu global.
Pour un menu de groupe ou de coalition, utiliser les variantes `ForGroup` ou `ForCoalition` et ajouter l'audience à la clé.
Il ne traite ni les libellés en double, ni les paramètres en table, ni la pagination.

```lua
-- StableMenu: renders an F10 menu by difference and parks every freed id.
-- Global menu only; for a group menu, use the ForGroup variants and add the group id to the key.
local PARKING_GROUP_ID = 999999 -- a group id no player can hold

local StableMenu = {}
StableMenu.__index = StableMenu

function StableMenu.new()
  return setmetatable({ rendered = {}, parked = 0 }, StableMenu)
end

local function onParkedClick()
  env.info("click on a removed F10 entry, ignored")
end

-- Removes one entry, then parks the id it freed before anything else can take it.
function StableMenu:_remove(entry)
  missionCommands.removeItem(entry.path)
  self.rendered[entry.key] = nil
  self.parked = self.parked + 1
  missionCommands.addCommandForGroup(PARKING_GROUP_ID, "parked " .. self.parked, nil, onParkedClick)
end

-- tree: a list of nodes, each { label = ..., children = {...} } for a submenu
-- or { label = ..., fn = ..., arg = ... } for a command.
function StableMenu:render(tree)
  local seen = {}
  local function walk(nodes, parentKey, parentPath, depth)
    for _, node in ipairs(nodes) do
      local kind = node.children and "menu" or "command"
      local key = parentKey .. "/" .. kind .. ":" .. node.label
      seen[key] = true
      local entry = self.rendered[key]
      local unchanged = entry and (kind == "menu" or (entry.fn == node.fn and entry.arg == node.arg))
      if not unchanged then
        if entry then
          self:_remove(entry) -- a command whose callback or argument changed
        end
        local path
        if kind == "menu" then
          path = missionCommands.addSubMenu(node.label, parentPath)
        else
          path = missionCommands.addCommand(node.label, parentPath, node.fn, node.arg)
        end
        entry = { key = key, path = path, fn = node.fn, arg = node.arg, depth = depth }
        self.rendered[key] = entry
      end
      if node.children then
        walk(node.children, key, entry.path, depth + 1)
      end
    end
  end
  walk(tree, "", nil, 0)

  -- Remove what is no longer rendered, children before their parent: each removal frees one id.
  local gone = {}
  for key, entry in pairs(self.rendered) do
    if not seen[key] then
      gone[#gone + 1] = entry
    end
  end
  table.sort(gone, function(a, b)
    return a.depth > b.depth
  end)
  for _, entry in ipairs(gone) do
    self:_remove(entry)
  end
end

return StableMenu
```

Le squelette a été vérifié sous Lua 5.1 contre une doublure de `missionCommands` qui recycle les identifiants comme mesuré, et non en jeu :

| Cas | Résultat |
|---|---|
| reconstruction naïve, clic périmé sur B (contrôle de la doublure) | C, comme en jeu |
| rendu identique | 0 appel à DCS, clic périmé sur B → B |
| A remplacé par E | clic périmé sur B → B ; sur A → commande inerte |
| sous-menu `Liste` supprimé | clic périmé sur E → commande inerte |

Retirer la ligne de parking, ou désactiver la réutilisation des entrées, fait tomber trois de ces vérifications chacune.

## 6. Exemples

### 6.1 VEAF Mission Creation Tools

VMCT construit le menu VEAF par `veafRadio.RadioMenuBuilder` ([veafRadio.lua](../../src/scripts/veaf/veafRadio.lua)).
Avant le correctif, `rebuild()` supprimait la racine VEAF et recréait tout l'arbre, pour tous les groupes, à l'arrivée de chaque joueur humain et sur une trentaine d'autres événements : zones de combat, missions CAS, transport, assets, spawn.

La PR [VEAF/VEAF-Mission-Creation-Tools#1113](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/1113) applique le patron :

- **Rendu par différence** : chaque création d'une entrée du menu VEAF passe par `RadioMenuBuilder:_render`, avec la clé de la section 5.1. La comparaison des paramètres (`_sameValue`) reconnaît deux objets DCS identiques à leur `id_`. L'arrivée d'un joueur n'ajoute plus que les commandes de son groupe, et un rafraîchissement sans changement ne fait plus aucun appel à DCS.
- **Parking** : `RadioMenuBuilder:_removeEntry` crée après chaque suppression une commande inerte pour `veafRadio.PARKING_GROUP_ID = 999999`.
- **Ordre** : ajout en fin de liste. Les menus VEAF n'ont pas d'ordre déclaré, seulement un tri alphabétique au premier affichage.
- **Pages stables** : l'[ADR 0013](../adr/0013-radio-menu-pagination.md) a été amendé avec les règles de la section 5.4.

Vérifié en jeu, le code chargé à chaud dans une mission de démonstration :

| Essai | Pendant que le joueur lit un sous-menu | Clic | Résultat |
|---|---|---|---|
| ajout ailleurs | une entrée est ajoutée au menu VEAF | B | **B** ✅ |
| remplacement | A est supprimé et E ajouté | A | **rien** ✅ |
| ajout dans un menu paginé, pages stables | une entrée est ajoutée au menu racine | B | **B** ✅, un seul appel à DCS au lieu de 40 |

C'est l'essai en jeu qui a révélé le problème de pagination : avant les pages stables, un seul ajout à la racine faisait changer de page les entrées suivantes, donc les faisait recréer, soit 40 appels à DCS, et la nouvelle entrée atterrissait après « Page suivante ».

### 6.2 CTLD

CTLD reconstruisait le menu d'un groupe à chaque rafraîchissement, immédiatement ou 4 secondes plus tard selon son ADR 0015.
L'issue [VEAF/CTLD#257](https://github.com/VEAF/CTLD/issues/257) lui a apporté la mesure, et la PR [VEAF/CTLD#261](https://github.com/VEAF/CTLD/pull/261) le patron ; son ADR 0027 remplace l'ADR 0015.

Le principe est le même, mais trois choix diffèrent de VMCT, parce que les contraintes diffèrent :

- **Un point d'entrée unique** (`ctld.MenuManager._dispatch`, argument `{ groupId, key }`) : CTLD crée une nouvelle fonction à chaque rafraîchissement et ne peut pas comparer les callbacks ; le dispatcher retrouve la commande au moment du clic. C'est le premier piège de la section 5.1.
- **L'ordre déclaré est respecté** : les menus CTLD ont un ordre défini, et des entrées désactivées puis réactivées doivent retrouver leur place. Une insertion recrée les entrées qui la suivent, ce que le parking rend sûr.
- **Le délai de 4 secondes disparaît**, remplacé par un debounce de 0,15 seconde.

CTLD a aussi écrit une doublure de `missionCommands` qui recycle les identifiants comme mesuré, sur laquelle sa suite de tests reproduit le « clic sur B, C déclenché ».
Au 2026-10-10, la vérification en jeu d'une mission CTLD reste à faire.

## 7. Check-list pour un menu F10

1. Ne jamais supprimer et recréer un menu entier, ni immédiatement, ni après un délai.
2. Donner à chaque entrée une clé stable : parent, audience, nature, libellé.
3. Réutiliser une entrée dont la fonction et les paramètres n'ont pas changé ; comparer les objets DCS par `id_`, et ne pas recréer les fonctions à chaque rendu.
4. Supprimer les entrées disparues, les enfants avant leur parent.
5. Après chaque suppression, garer l'identifiant libéré sur une commande inerte d'un groupe inexistant, avant toute autre création.
6. Choisir entre ajout en fin de liste et recréation des entrées suivantes ; ne jamais déplacer une entrée sans la garer.
7. Dans un menu paginé, garder les pages stables.
8. Pour vérifier, mesurer sur une mission redémarrée, un test à la fois, avec un témoin.

## 8. Limites et questions ouvertes

- **Les mesures ont été faites en solo.** Les signalements venaient du multijoueur et concordent, mais aucune mesure n'a été faite sur un serveur dédié.
- **VMCT a une option pour mesurer en multijoueur** : `RADIO.menu_stats: true` dans le `mission.yaml` écrit dans `dcs.log`, à chaque rafraîchissement, la taille du menu et ce qui a changé. Elle sert à mesurer le point précédent sur une vraie mission.
- **Les menus de coalition n'ont pas été mesurés.** Le stock unique d'identifiants rend le même comportement très probable.
- **L'ordre exact de réutilisation est déduit**, pas mesuré directement. Le correctif ne dépend pas de cet ordre.
- **Les commandes inertes s'accumulent** sans borne pendant une mission. Jusqu'à 50 000, leur coût n'est pas mesurable en solo (section 5.2) ; en multijoueur, ce que le serveur transmet aux clients pour un groupe sans membres n'a pas été mesuré.

## Références

- Le piège, avec ses mesures : `f10-menu-entry-id-is-recycled` dans [known-limitations.yaml](../../src/python/veaf-tools/veaf_libs/data/known-limitations.yaml), page générée [dcs-runtime-traps.md](../agents/dcs-runtime-traps.md).
- VMCT : PR [VEAF/VEAF-Mission-Creation-Tools#1113](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/1113) ; `RadioMenuBuilder:rebuild`, `_render` et `_removeEntry` dans [veafRadio.lua](../../src/scripts/veaf/veafRadio.lua) ; tests `TestVeafRadioIncrementalRender` dans [test_veafRadio.lua](../../test/lua/test_veafRadio.lua) ; pagination, [ADR 0013](../adr/0013-radio-menu-pagination.md).
- CTLD : issue [VEAF/CTLD#257](https://github.com/VEAF/CTLD/issues/257), PR [VEAF/CTLD#261](https://github.com/VEAF/CTLD/pull/261).
- Un fil voisin sur le forum DCS, sans rapport direct : [missionCommands.removeItem bug](https://forum.dcs.world/topic/96887-missioncommandsremoveitem-bug/).
