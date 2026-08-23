# FIX-CONVOY-MENU-NESTING — six radio commands, each alone inside its own submenu

Status: ✅ done — shipped in 6.15.32

Reported in game on 2026-08-22, while checking the convoy itinerary feature:

> *"pourquoi les commandes sont dans des sous menus ? (`F4 - Arrêter le convoi le plus proche sur
> place…` → `F1 - Arrepter le convoi le plus proche sur place…`)"*

Every convoy command costs two keystrokes instead of one, and the second menu repeats the label of the
first — so the pilot reads the same sentence twice to reach a single item.

## The convention is gratuitous, and that was checked rather than assumed

`veafSpawnCore.lua` builds each command as a submenu holding one command of the same name:

```lua
local menuPath = veafRadio.addSubMenu(veaf.t("menu.spawn.convoy_advance"), veafSpawn.rootPath)
veafRadio.addCommandToSubmenu(veaf.t("menu.spawn.convoy_advance"), menuPath, veafSpawn.advanceClosestConvoy, nil, veafRadio.USAGE_ForGroup)
```

Nothing forces it:

- `veafCarrierOperations` adds **several** `USAGE_ForGroup` commands into one shared submenu
  (`carrier.menuPath`), so the usage flag is not what demands a dedicated parent;
- `convoy_cleanup`, **three lines below in the same block**, is added straight to `veafSpawn.rootPath`
  with `addSecuredCommandToSubmenu`.

So the flat form is already in use next to the nested one.

## Six commands, not four

The pattern **predates** `FEAT-CONVOY-WAYPOINTS`: `convoy_mark` and `convoy_mark_route` were already
written this way, and the four itinerary commands copied their neighbour. Fixing only the new four would
leave the menu half-flat, which is worse than consistent nesting — so all six move together.

| Command | i18n key |
|---|---|
| Mark closest convoy | `menu.spawn.convoy_mark` |
| Mark closest convoy route | `menu.spawn.convoy_mark_route` |
| Send closest convoy to its next point | `menu.spawn.convoy_advance` |
| Hold closest convoy at its next point | `menu.spawn.convoy_hold` |
| Halt closest convoy where it stands | `menu.spawn.convoy_stop` |
| Resume closest convoy after a halt | `menu.spawn.convoy_move` |

## Definition of done

- [ ] The six commands sit directly under the spawn root, one keystroke each
- [ ] `USAGE_ForGroup` is preserved on all six — it is what makes the command act on the caller's group,
      and dropping it would break them silently rather than visibly
- [ ] A test pins the flat shape, so the nested form cannot creep back by copy-paste from an older block
- [ ] Labels unchanged: this is about depth, not wording
