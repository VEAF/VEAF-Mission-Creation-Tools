# Lot FEAT-COMBATZONE-MENU-COALITION — a combat zone's F10 menu is shown to its own side only

Status: 🔄 in-progress
Branch: feature/FEAT-COMBATZONE-MENU-COALITION

## Problem Statement

Every combat zone's F10 submenu is global: both coalitions see every zone. That menu is not
read-only — it is how a zone gets **activated**, its smoke popped, its info requested. So with
red-side zones now possible (FEAT-COMBATZONE-RED-SIDE), a blue player sees and can trigger the
red side's zones, and vice versa.

## Solution

DCS supports this natively — `missionCommands.addSubMenuForCoalition` /
`addCommandForCoalition` / `removeItemForCoalition` — so no per-group duplication is needed.
The gap is that `veafRadio`'s menu builder only ever calls the global and the per-group
variants.

**1. `veafRadio` gains coalition-scoped menu nodes.** `veafRadio.addSubMenu(title, parent,
coalitionSide)` records the side on the logical node; `RadioMenuBuilder` then renders that
subtree with the `ForCoalition` API. The side is **inherited** by everything below the node —
child submenus, commands, and the render-time pagination pages (ADR 0013) — otherwise a global
child would sit under a coalition-scoped parent, which DCS has no coherent meaning for.

A `USAGE_ForGroup` / `USAGE_ForUnit` command inside a restricted subtree is only emitted for
human groups of that coalition. Without this, DCS would be asked to attach a per-group command
under a path that group cannot see. This requires `veafRadio.humanGroups` to record each
group's coalition, which it did not.

`rebuild()` also has to remove the coalition-scoped nodes explicitly: it only ever called the
global `removeItem` on the root, and the menu is rebuilt on every birth event, so anything the
global removal does not reach would accumulate a duplicate menu per player join.

**2. Each zone defaults to its own side.** A zone shows its menu to `getFriendlyCoalition()` —
the opposite of `enemy_coalition`. `radio_menu_coalition: RED | BLUE | ALL` overrides it, with
`ALL` restoring today's global menu (for an umpire in a red slot who must trigger a blue zone).

This **changes the behaviour of existing missions**: a zone with no `enemy_coalition` now shows
its menu to blue only. Chosen deliberately (David, over the two alternatives) — on a mission
where both sides are played, deducing it is what is wanted, and requiring the key on every zone
would be noise. Missions whose player slots are all blue see no difference.

## Risk to verify in-game

Whether DCS accepts a coalition-scoped submenu **under a global parent** — the VEAF root menu
and `COMBAT ZONES` stay global — cannot be proven from the sources or the mocks. The unit tests
pin which API is called with which arguments, not DCS's reaction. If DCS turns out to require a
coalition-scoped parent chain, the fallback is to also scope the `COMBAT ZONES` parent per
coalition, which is a change in `veafCombatZone.buildRadioMenu`, not in this design.

The parent menu stays global on purpose: a `radio_group_name` submenu may hold zones of both
sides, so a side can see the `COMBAT ZONES` entry without the other side's zones under it.

## Testing Decisions

- `veafRadio`: a node with a side renders through `addSubMenuForCoalition`; children and
  pagination pages inherit it; a `ForGroup` command reaches only that coalition's groups; a node
  without a side still uses the global API (regression guard); `rebuild` removes scoped nodes.
- `veafCombatZone`: the menu side defaults to the friendly coalition, follows
  `enemy_coalition`, and `ALL` makes it global again.
- Python: `radio_menu_coalition` emits the setter, is case-insensitive, rejects an unknown
  value, and emits nothing when absent.
- DCS mocks gain the three `ForCoalition` entries (the `dcs-mock-coverage` CI job).

## Out of Scope

- Scoping the `COMBAT ZONES` root or the `radio_group_name` submenu (see above).
- The other modules' menus (QRA, AirWaves…): they already have a per-group restriction and no
  one asked for a coalition one.
